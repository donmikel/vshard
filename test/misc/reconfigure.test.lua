test_run = require('test_run').new()
test_run:cmd("push filter '.*/init.lua.*[0-9]+: ' to ''")

REPLICASET_1 = { 'storage_1_a', 'storage_1_b' }
REPLICASET_2 = { 'storage_2_a', 'storage_2_b' }

test_run:create_cluster(REPLICASET_1, 'misc')
test_run:create_cluster(REPLICASET_2, 'misc')
util = require('util')
util.wait_master(test_run, REPLICASET_1, 'storage_1_a')
util.wait_master(test_run, REPLICASET_2, 'storage_2_a')

test_run:cmd('create server router_1 with script="misc/router_1.lua", wait=True, wait_load=True')
test_run:cmd('start server router_1')

test_run:switch('default')
cfg = require'localcfg'
rs1_id = 'cbf06940-0790-498b-948d-042b62cf3d29'
s1_2_id = '3de2e3e1-9ebe-4d0d-abb1-26d301b84633'
rs2_id = 'ac522f65-aa94-4134-9f64-51ee384f1a54'
s2_1_id = '1e02ae8a-afc0-4e91-ba34-843a356b8ed7'
s2_2_id = '001688c3-66f8-4a31-8e19-036c17d489c2'
rs3_id = '910ee49b-2540-41b6-9b8c-c976bef1bb17'
s3_1_id = 'ee34807e-be5c-4ae3-8348-e97be227a305'

cfg.sharding[rs1_id].replicas[s1_2_id] = nil
cfg.sharding[rs2_id].replicas[s2_1_id].master = nil
cfg.sharding[rs2_id].replicas[s2_2_id].master = true
cfg.sharding[rs3_id] = {replicas = {[s3_1_id] = {uri = "storage:storage@127.0.0.1:3306", name = 'storage_3_a', master = true}}}

REPLICASET_3 = {'storage_3_a'}
test_run:create_cluster(REPLICASET_3, 'misc')

-- test for unknown uuid
test_run:cmd('switch storage_1_a')
util = require('util')
util.check_error(vshard.storage.cfg, cfg, 'unknow uuid')

--
-- Ensure that in a case of error storage internals are not
-- changed.
--
not vshard.storage.internal.collect_lua_garbage
vshard.storage.internal.sync_timeout
cfg.sync_timeout = 100
cfg.collect_lua_garbage = true
cfg.rebalancer_max_receiving = 1000
cfg.collect_bucket_garbage_interval = 100
cfg.invalid_option = 'kek'
vshard.storage.cfg(cfg, names.storage_1_a)
not vshard.storage.internal.collect_lua_garbage
vshard.storage.internal.sync_timeout
vshard.storage.internal.rebalancer_max_receiving ~= 1000
vshard.storage.internal.collect_bucket_garbage_interval ~= 100
cfg.sync_timeout = nil
cfg.collect_lua_garbage = nil
cfg.rebalancer_max_receiving = nil
cfg.collect_bucket_garbage_interval = nil
cfg.invalid_option = nil

--
-- gh-59: provide trigger on master enable/disable.
--
disable_count = 0
enable_count = 0
function on_master_disable() disable_count = disable_count + 1 end
function on_master_enable() enable_count = enable_count + 1 end
vshard.storage.on_master_disable(on_master_disable)
vshard.storage.on_master_enable(on_master_enable)

-- test without master
for _, rs in pairs(cfg.sharding) do for _, s in pairs(rs.replicas) do s.master = nil end end
vshard.storage.cfg(cfg, box.info.uuid)

disable_count

test_run:cmd('switch default')

test_run:cmd('stop server storage_1_b')

cmd = 'cfg.sharding = require"json".decode([[' .. require"json".encode(cfg.sharding) .. ']])'
test_run:cmd('eval storage_1_a \'' .. cmd .. '\'')
test_run:cmd('eval storage_2_a \'' .. cmd .. '\'')
test_run:cmd('eval storage_2_b \'' .. cmd .. '\'')
test_run:cmd('eval storage_3_a \'' .. cmd .. '\'')
test_run:cmd('eval router_1 \'' .. cmd .. '\'')
test_run:switch('storage_1_a')
vshard.storage.cfg(cfg, names['storage_1_a'])
enable_count

test_run:switch('storage_2_a')
vshard.storage.cfg(cfg, names['storage_2_a'])

test_run:switch('storage_2_b')
vshard.storage.cfg(cfg, names['storage_2_b'])

test_run:switch('router_1')
--
-- Ensure that in a case of error router internals are not
-- changed.
--
not vshard.router.internal.collect_lua_garbage
cfg.collect_lua_garbage = true
cfg.invalid_option = 'kek'
vshard.router.cfg(cfg)
not vshard.router.internal.collect_lua_garbage
cfg.invalid_option = nil
cfg.collect_lua_garbage = nil
vshard.router.cfg(cfg)

test_run:cmd('switch default')

REPLICASET_1 = {'storage_1_a'}
util.wait_master(test_run, REPLICASET_1, 'storage_1_a')
util.wait_master(test_run, REPLICASET_2, 'storage_2_a')
util.wait_master(test_run, REPLICASET_3, 'storage_3_a')

-- Check correctness on each replicaset.
test_run:switch('storage_1_a')
info = vshard.storage.info()
uris = {}
for k,v in pairs(info.replicasets) do table.insert(uris, v.master.uri) end
table.sort(uris)
uris
box.cfg.replication

test_run:switch('storage_2_a')
info = vshard.storage.info()
uris = {}
for k,v in pairs(info.replicasets) do table.insert(uris, v.master.uri) end
table.sort(uris)
uris
box.cfg.replication

test_run:switch('storage_2_b')
info = vshard.storage.info()
uris = {}
for k,v in pairs(info.replicasets) do table.insert(uris, v.master.uri) end
table.sort(uris)
uris
box.cfg.replication

test_run:switch('storage_3_a')
info = vshard.storage.info()
uris = {}
for k,v in pairs(info.replicasets) do table.insert(uris, v.master.uri) end
table.sort(uris)
uris
box.cfg.replication

test_run:switch('router_1')
info = vshard.router.info()
uris = {}
for k,v in pairs(info.replicasets) do table.insert(uris, v.master.uri) end
table.sort(uris)
uris

test_run:switch('default')

test_run:cmd('stop server router_1')
test_run:cmd('cleanup server router_1')
test_run:drop_cluster(REPLICASET_1)
test_run:drop_cluster(REPLICASET_2)
test_run:drop_cluster(REPLICASET_3)
