--
-- Lua bridge for some of the git commands.
--
local os = require('os')

local temp_file = 'some_strange_rare_unique_file_name_for_git_util'
local function exec_cmd(options, cmd, args, files, fout)
    files = files or ''
    options = options or ''
    args = args or ''
    local shell_cmd
    shell_cmd = string.format('git %s %s %s %s', options, cmd, args, files)
    if fout then
        shell_cmd = shell_cmd .. ' >' .. fout
    end
    local res = os.execute(shell_cmd)
    assert(res == 0, 'Git cmd error: ' .. res)
end

local function log_hashes(options, args, files)
    args = args .. " --format='%h'"
    exec_cmd(options, 'log', args, files, temp_file)
    local lines = {}
    for line in io.lines(temp_file) do
        table.insert(lines, line)
    end
    os.remove(temp_file)
    return lines
end


return {
    exec_cmd = exec_cmd,
    log_hashes = log_hashes
}
