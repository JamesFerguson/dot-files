# frozen_string_literal: true

require 'json'
require 'rbconfig'
require 'time'

# Records Claude Code's current default model, so the status line can flag a session running anything
# else. A fresh headless session with no setting sources can't be overridden by a settings `model`, a
# resumed conversation or /model, so the model it starts on is the default. Its prompt is /cost, which
# Claude Code answers itself: no request reaches the API and the probe uses no tokens. Also records the
# models on offer, so the status line can name an advisor set by alias in settings.json.
#
# The probe takes about 3 seconds, so a draw never waits for it: when the record is stale the draw
# starts it in the background and carries on with the old record, and a later draw picks up the new one.
module DefaultModel
  MAX_AGE  = 600 # seconds a record stays fresh
  LOCK_AGE = 120 # an attempt holds the lock this long; the probe gives up at 90s
  TIMEOUT  = 90
  # What launchd gives a job. Draws run inside a session, and its env (settings.json's `env` block
  # among it) could change the model a fresh session opens on.
  PROBE_ENV = %w[HOME USER LOGNAME SHELL TMPDIR].freeze
  CLAUDE_DIRS = ['~/.local/bin', '/opt/homebrew/bin', '/usr/local/bin', '~/.claude/local'].freeze

  module_function

  # Starts the probe unless the record is fresh or another draw started one recently. A failed
  # probe leaves the record alone, so the lock also spaces out retries.
  def refresh(record:, lock:, log: File::NULL, probe: nil, now: Time.now)
    return :fresh if File.exist?(record) && now - File.mtime(record) < MAX_AGE
    return :no_claude unless (probe ||= probe_command(record))
    return :locked unless take_lock(lock, now)

    pid = Process.spawn(ENV.slice(*PROBE_ENV), *Array(probe), unsetenv_others: true,
                        in: File::NULL, out: [log, 'a'], err: [:child, :out], pgroup: true)
    Process.detach(pid)
    :started
  rescue SystemCallError
    :failed
  end

  def probe_command(record)
    claude = find_claude or return nil
    [RbConfig.ruby, __FILE__, claude, record]
  end

  def find_claude
    dirs = ENV.fetch('PATH', '').split(File::PATH_SEPARATOR) + CLAUDE_DIRS.map { File.expand_path(_1) }
    dirs.map { File.join(_1, 'claude') }.find { File.executable?(_1) }
  end

  def take_lock(lock, now)
    File.open(lock, File::WRONLY | File::CREAT | File::EXCL).close
    true
  rescue Errno::EEXIST
    return false if now - File.mtime(lock) < LOCK_AGE

    File.unlink(lock)
    retry
  end

  # Runs in the background process: opens a fresh session, reads its init event and writes the record.
  def probe(claude, record)
    ENV['PATH'] = [File.dirname(claude), '/usr/bin', '/bin'].join(File::PATH_SEPARATOR)
    init = first_event(claude) or return log("no init event from claude; keeping #{record}")

    write(record, 'version' => init['claude_code_version'], 'default_id' => init['model'],
                  'offered' => offered, 'checked_at' => Time.now.utc.iso8601)
    log("default #{init['model']} on Claude Code #{init['claude_code_version']}")
  end

  def first_event(claude)
    argv = [claude, '-p', '--output-format', 'stream-json', '--verbose', '--setting-sources', '',
            '--no-session-persistence', '/cost']
    line = IO.popen(argv, chdir: Dir.home, err: File::NULL) do |io|
      IO.select([io], nil, nil, TIMEOUT) && io.gets.tap { Process.kill('TERM', io.pid) rescue nil }
    end
    event = JSON.parse(line.to_s) rescue nil
    event if event&.dig('subtype') == 'init' && event['model'] && event['claude_code_version']
  end

  # Model ids Claude Code offers beyond the default, e.g. Fable when it isn't the default.
  def offered
    options = JSON.parse(File.read(File.expand_path('~/.claude.json')))['additionalModelOptionsCache']
    (options.is_a?(Hash) ? options.values : Array(options)).filter_map { _1['value'] if _1.is_a?(Hash) }
  rescue StandardError
    []
  end

  def write(record, data)
    tmp = "#{record}.tmp.#{Process.pid}"
    File.write(tmp, JSON.pretty_generate(data))
    File.rename(tmp, record)
  end

  def log(text) = puts("#{Time.now.strftime('%F %T')} #{text}")
end

DefaultModel.probe(*ARGV) if $PROGRAM_NAME == __FILE__
