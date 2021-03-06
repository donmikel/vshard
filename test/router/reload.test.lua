test_run = require('test_run').new()
REPLICASET_1 = { 'storage_1_a', 'storage_1_b' }
REPLICASET_2 = { 'storage_2_a', 'storage_2_b' }
test_run:create_cluster(REPLICASET_1, 'storage')
test_run:create_cluster(REPLICASET_2, 'storage')
util = require('util')
util.wait_master(test_run, REPLICASET_1, 'storage_1_a')
util.wait_master(test_run, REPLICASET_2, 'storage_2_a')
test_run:cmd("create server router_1 with script='router/router_1.lua'")
test_run:cmd("start server router_1")

test_run:switch('router_1')
fiber = require('fiber')
vshard.router.bootstrap()

while test_run:grep_log('router_1', 'All replicas are ok') == nil do fiber.sleep(0.1) end
while test_run:grep_log('router_1', 'buckets: was 0, became 1500') == nil do fiber.sleep(0.1) vshard.router.discovery_wakeup() end

--
-- Gh-72: allow reload. Test simple reload, error during
-- reloading, ensure the fibers are restarted on reload.
--

assert(rawget(_G, '__module_vshard_router') ~= nil)
vshard.router.module_version()
test_run:cmd("setopt delimiter ';'")
function check_reloaded()
	for k, v in pairs(old_internal) do
		if v == vshard.router.internal[k] then
			return k
		end
	end
end;
function check_not_reloaded()
	for k, v in pairs(old_internal) do
		if v ~= vshard.router.internal[k] then
			return k
		end
	end
end;
function copy_functions(t)
	local ret = {}
	for k, v in pairs(t) do
		if type(v) == 'function' then
			ret[k] = v
		end
	end
	return ret
end;
test_run:cmd("setopt delimiter ''");
--
-- Simple reload. All functions are reloaded and they have
-- another pointers in vshard.router.internal.
--
old_internal = copy_functions(vshard.router.internal)
package.loaded["vshard.router"] = nil
_ = require('vshard.router')
vshard.router.module_version()

check_reloaded()

while test_run:grep_log('router_1', 'Failover has been started') == nil do fiber.sleep(0.1) end
while test_run:grep_log('router_1', 'Discovery has been started') == nil do fiber.sleep(0.1) vshard.router.discovery_wakeup() end

check_reloaded()

--
-- Error during reload - in such a case no function can be
-- updated. Reload is atomic.
--
vshard.router.internal.errinj.ERRINJ_RELOAD = true
old_internal = copy_functions(vshard.router.internal)
package.loaded["vshard.router"] = nil
util = require('util')
util.check_error(require, 'vshard.router')
check_not_reloaded()
vshard.router.module_version()

--
-- A next reload is ok, and all functions are updated.
--
vshard.router.internal.errinj.ERRINJ_RELOAD = false
old_internal = copy_functions(vshard.router.internal)
package.loaded["vshard.router"] = nil
_ = require('vshard.router')
vshard.router.module_version()
check_reloaded()

test_run:switch('default')
test_run:cmd('stop server router_1')
test_run:cmd('cleanup server router_1')
test_run:drop_cluster(REPLICASET_2)
test_run:drop_cluster(REPLICASET_1)
test_run:cmd('clear filter')
