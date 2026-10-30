# frozen_string_literal: true

# Keeps the status line's record of Claude Code's default model fresh.
#
# statusline-default-model.zsh writes the record from a fresh `claude -p /cost` session, which uses no
# tokens but takes about 3 seconds. So a draw never waits for it: when the record is stale the draw
# starts the probe in the background and carries on with the old record, and a later draw picks up
# the new one.
module DefaultModel
  MAX_AGE  = 600 # seconds a record stays fresh
  LOCK_AGE = 120 # an attempt holds the lock this long; the probe times out at 90s
  # What launchd gives a job. Draws run inside a session, and its env (settings.json's `env` block
  # among it) could change the model a fresh session opens on.
  PROBE_ENV = %w[HOME USER LOGNAME SHELL TMPDIR STATUSLINE_DEFAULT_MODEL_CACHE].freeze

  module_function

  # Starts the probe unless the record is fresh or another draw started one recently. A failed
  # probe leaves the record alone, so the lock also spaces out retries.
  def refresh(record:, lock:, probe:, log: File::NULL, now: Time.now)
    return :fresh if File.exist?(record) && now - File.mtime(record) < MAX_AGE
    return :locked unless take_lock(lock, now)

    pid = Process.spawn(ENV.slice(*PROBE_ENV), probe, unsetenv_others: true,
                        in: File::NULL, out: [log, 'a'], err: [:child, :out], pgroup: true)
    Process.detach(pid)
    :started
  rescue SystemCallError
    :failed
  end

  def take_lock(lock, now)
    File.open(lock, File::WRONLY | File::CREAT | File::EXCL).close
    true
  rescue Errno::EEXIST
    return false if now - File.mtime(lock) < LOCK_AGE

    File.unlink(lock)
    retry
  end
end
