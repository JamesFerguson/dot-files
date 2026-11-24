# frozen_string_literal: true

# ruby ~/.claude/skills/git-cascade/git-cascade-test.rb
# Builds throwaway repos (with a bare origin) under a temp dir.

require 'minitest/autorun'
require 'tmpdir'
require 'stringio'
require 'open3'
load File.expand_path('git-cascade', __dir__)

class GitCascadeTest < Minitest::Test
  def setup
    @tmp = Dir.mktmpdir('git-cascade-test')
    @origin = File.join(@tmp, 'origin.git')
    @repo = File.join(@tmp, 'repo')
    sh(@tmp, 'git', 'init', '--quiet', '--bare', '-b', 'main', @origin)
    sh(@tmp, 'git', 'clone', '--quiet', @origin, @repo)
    git('config', 'user.email', 't@example.com')
    git('config', 'user.name', 'T')
    write('README', "base\n")
    git('add', 'README')
    git('commit', '--quiet', '-m', 'base')
    git('push', '--quiet', '-u', 'origin', 'main')
    # main ← a ← b ← c, each with its own file
    %w[a b c].each_with_index do |name, i|
      git('checkout', '--quiet', '-b', name, i.zero? ? 'main' : %w[a b c][i - 1])
      write("#{name}.txt", "#{name}\n")
      git('add', "#{name}.txt")
      git('commit', '--quiet', '-m', name)
      git('push', '--quiet', '-u', 'origin', name)
    end
  end

  def teardown = FileUtils.rm_rf(@tmp)

  def test_commits_on_the_named_branch_from_the_top_and_carries_it_up
    git('checkout', '--quiet', 'c')
    write('a.txt', "a changed\n")

    assert_equal 0, cascade('commit', 'a', '-m', 'change a', 'a.txt')

    assert_equal 'a', git('branch', '--show-current')
    assert_equal 'change a', git('log', '-1', '--format=%s', 'a')
    %w[b c].each do |b|
      assert_equal "a changed\n", git('show', "#{b}:a.txt") + "\n"
      assert ancestor?('a', b)
    end
    assert_equal %w[c b change\ a a base], git('log', '--format=%s', 'c').split("\n")
  end

  def test_pushes_every_moved_branch_with_a_lease
    write('b.txt', "b changed\n")

    assert_equal 0, cascade('commit', 'b', '-m', 'change b', '--push', 'b.txt')

    %w[b c].each { |b| assert_equal git('rev-parse', b), git('rev-parse', "origin/#{b}") }
    assert_equal git('rev-parse', 'a'), git('rev-parse', 'origin/a')
  end

  def test_moves_both_branches_of_a_fork
    git('checkout', '--quiet', '-b', 'b2', 'a')
    write('b2.txt', "b2\n")
    git('add', 'b2.txt')
    git('commit', '--quiet', '-m', 'b2')
    write('a.txt', "a changed\n")

    assert_equal 0, cascade('commit', 'a', '-m', 'change a', 'a.txt')

    %w[b c b2].each { |b| assert ancestor?('a', b), "#{b} should sit on the new a" }
  end

  def test_refuses_when_another_file_is_already_staged
    write('a.txt', "a changed\n")
    write('README', "stray\n")
    git('add', 'README')

    assert_equal 1, cascade('commit', 'a', '-m', 'change a', 'a.txt')

    assert_match(/already staged: README/, @output.string)
    assert_equal 'a', git('log', '-1', '--format=%s', 'a')
  end

  def test_refuses_to_commit_to_main
    write('README', "x\n")

    assert_equal 1, cascade('commit', 'main', '-m', 'x', 'README')
    assert_match(/refusing to commit straight to main/, @output.string)
  end

  def test_refuses_a_branch_held_by_another_worktree
    git('checkout', '--quiet', 'a')
    sh(@repo, 'git', 'worktree', 'add', '--quiet', File.join(@tmp, 'wt'), 'c')
    write('a.txt', "a changed\n")

    assert_equal 1, cascade('commit', 'a', '-m', 'change a', 'a.txt')
    assert_match(/c checked out in another worktree/, @output.string)
    assert_equal 'a', git('log', '-1', '--format=%s', 'a')
  end

  def test_aborts_a_conflicting_rebase_and_leaves_the_stack_alone
    git('checkout', '--quiet', 'b')
    write('a.txt', "b's version\n")
    git('commit', '--quiet', '-am', 'b edits a.txt')
    c_before = git('rev-parse', 'c')
    git('checkout', '--quiet', 'a')
    write('a.txt', "a's version\n")

    assert_equal 1, cascade('commit', 'a', '-m', 'change a', 'a.txt')

    assert_match(/aborted/, @output.string)
    assert_equal c_before, git('rev-parse', 'c')
    assert_empty Dir.glob(File.join(@repo, '.git', 'rebase-*'))
  end

  def test_refuses_to_switch_when_the_edits_clash_with_the_branch
    git('checkout', '--quiet', 'b')
    write('a.txt', "b's version\n")
    git('commit', '--quiet', '-am', 'b edits a.txt')
    write('a.txt', "edited on b\n")

    assert_equal 1, cascade('commit', 'a', '-m', 'change a', 'a.txt')

    assert_match(/would be overwritten by checkout/, @output.string)
    assert_equal 'b', git('branch', '--show-current')
    assert_equal 'a', git('log', '-1', '--format=%s', 'a')
  end

  def test_restacks_after_the_base_was_changed_some_other_way
    git('checkout', '--quiet', 'a')
    old_a = git('rev-parse', 'a')
    write('a.txt', "amended\n")
    git('commit', '--quiet', '--amend', '-am', 'a, amended')

    assert_equal 0, cascade('restack', 'a', '--from', old_a)

    assert_equal %w[c b a,\ amended base], git('log', '--format=%s', 'c').split("\n")
  end

  def test_restack_spots_a_stack_that_lost_commits
    stack = GitCascade::Stack.new(GitCascade::Git.new(@repo), 'a', git('rev-parse', 'a'))
    git('checkout', '--quiet', 'a')
    write('a.txt', "a changed\n")
    git('commit', '--quiet', '-am', 'change a')
    git('branch', '--quiet', '-f', 'c', 'a') # what went wrong on 24 Nov
    git('rebase', '--quiet', '--onto', 'a', stack.old_base, 'b')

    problems = stack.verify

    assert(problems.any? { |p| p.start_with?('c: had 2 commits') }, problems.inspect)
  end

  private

  def cascade(*args)
    @output = StringIO.new
    GitCascade::CLI.new([*args, '-C', @repo], out: @output).run
  end

  def git(*args) = sh(@repo, 'git', *args).strip
  def ancestor?(a, b) = system('git', '-C', @repo, 'merge-base', '--is-ancestor', a, b)
  def write(path, text) = File.write(File.join(@repo, path), text)

  def sh(dir, *cmd)
    out, err, status = Open3.capture3(*cmd, chdir: dir)
    raise "#{cmd.join(' ')}: #{err}" unless status.success?

    out
  end
end
