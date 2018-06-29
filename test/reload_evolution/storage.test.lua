test_run = require('test_run').new()

git_util = require('git_util')
util = require('util')
os = require('os')
vshard_copy_path = util.PROJECT_BINARY_DIR .. '/test/var/vshard_git_tree_copy'
evolution_log = git_util.log_hashes('-C ' .. util.PROJECT_SOURCE_DIR, '', 'vshard/storage/reload_evolution.lua')
-- Cleanup the directory after a previous build.
os.execute('rm -rf ' .. vshard_copy_path)
git_util.exec_cmd('-C '.. util.PROJECT_SOURCE_DIR, 'worktree', 'add --detach ' .. vshard_copy_path)
-- Checkout the first commit with a reload_evolution mechanism.
git_util.exec_cmd('-C ' .. vshard_copy_path, 'checkout', evolution_log[#evolution_log] .. '~1')

REPLICASET_1 = { 'storage_1_a', 'storage_1_b' }
REPLICASET_2 = { 'storage_2_a', 'storage_2_b' }
test_run:create_cluster(REPLICASET_1, 'reload_evolution')
test_run:create_cluster(REPLICASET_2, 'reload_evolution')
util = require('util')
util.wait_master(test_run, REPLICASET_1, 'storage_1_a')
util.wait_master(test_run, REPLICASET_2, 'storage_2_a')

test_run:switch('storage_1_a')
vshard.storage.internal.reload_evolution_version
vshard.storage.bucket_force_create(1, vshard.consts.DEFAULT_BUCKET_COUNT / 2)
box.space.customer:insert({1, 1, 'customer_name'})

test_run:switch('storage_2_a')
fiber = require('fiber')
vshard.storage.bucket_force_create(vshard.consts.DEFAULT_BUCKET_COUNT / 2 + 1, vshard.consts.DEFAULT_BUCKET_COUNT / 2)
while test_run:grep_log('storage_2_a', 'The cluster is balanced ok') == nil do vshard.storage.rebalancer_wakeup() fiber.sleep(0.1) end

test_run:switch('default')
git_util.exec_cmd('-C ' .. vshard_copy_path, 'checkout', evolution_log[1])

test_run:switch('storage_1_a')
package.loaded["vshard.storage"] = nil
vshard.storage = require("vshard.storage")
test_run:grep_log('storage_1_a', 'vshard.storage.reload_evolution: upgraded to') ~= nil
vshard.storage.internal.reload_evolution_version
-- Make sure storage operates well.
vshard.storage.bucket_force_drop(2)
vshard.storage.bucket_force_create(2)
vshard.storage.buckets_info()[2]
vshard.storage.call(1, 'read', 'customer_lookup', {1})
vshard.storage.bucket_send(1, replicaset2_uuid)
vshard.storage.garbage_collector_wakeup()
fiber = require('fiber')
while box.space._bucket:get({1}) do fiber.sleep(0.01) end
test_run:switch('storage_2_a')
vshard.storage.bucket_send(1, replicaset1_uuid)
test_run:switch('storage_1_a')
vshard.storage.call(1, 'read', 'customer_lookup', {1})
-- Check info() does not fail.
vshard.storage.info() ~= nil

test_run:switch('default')
test_run:drop_cluster(REPLICASET_2)
test_run:drop_cluster(REPLICASET_1)
test_run:cmd('clear filter')
