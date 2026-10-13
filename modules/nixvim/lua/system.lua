-- `vim.system` for `vim.async` tasks. It resumes the task on the main loop,
-- where the API is usable, and closing the task terminates the process.
return function(cmd, opts)
  return vim.async.await(function(done)
    local proc = vim.system(cmd, opts, vim.schedule_wrap(done))

    return {
      is_closing = function()
        return proc:is_closing()
      end,
      close = function(_, closed)
        proc:kill("sigterm")
        closed()
      end,
    }
  end)
end
