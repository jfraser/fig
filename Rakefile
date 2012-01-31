# To build fig for ruby 1.8.7 on windows please see the README for instructions.
# It is not possible to do from the rake file anymore.

require 'fileutils'
require 'git'
require 'rake'
require 'rdoc/task'
require 'rspec/core/rake_task'
require 'rubygems'
require 'rubygems/package_task'

include FileUtils

major_version = nil
minor_version = nil
patch_version = nil
version = nil

File.open('VERSION', 'r') do |file|
  version = file.gets
  matches = version.match(/(\d+)\.(\d+)\.(\d+)/)
  major_version = matches[1]
  minor_version = matches[2]
  patch_version = matches[3]
end


def clean_git_working_directory?
  return %x<git ls-files --deleted --modified --others --exclude-standard> == ''
end

def tag_doesnt_exist_in_local_repo(git_repo, tag)
  return ! git_repo.tags.include?(tag)
end

def create_git_tag(git_repo)
  new_tag = "v#{version}"
  puts "Checking for an existing #{new_tag} tag."
  if tag_doesnt_exist_in_local_repo(git_repo, new_tag)
    puts "Creating #{new_tag} tag."
    #git_repo.add_tag(new_tag)
  end

  if tag_doesnt_exist_in_local_repo(git_repo, new_tag)
    "The tag was not successfully created. Aborting!"
    return nil
  end

  return new_tag
end

def push_to_remote_repo(git_repo, new_tag)
  if new_tag != nil
    puts "Pushing #{new_tag} to 'origin'."
    #git_repo.push('origin', new_tag)
  end

  return
end

def tag_and_push_to_git
  if clean_git_working_directory?
    git_repo = Git.open('.')
    new_tag = create_git_tag(git_repo)
    push_to_remote_repo(git_repo, new_tag)
  else
    puts "Cannot proceed with tag, push, and publish!"
    puts "Your environment is not clean."
    puts "The status of your local git repository:"
    puts %x<git status>
  end

  return new_tag != nil
end

def local_repo_is_updated?
  pull_results = %x{git pull 2>&1}
  if pull_results.chomp != "Already up-to-date."
    puts 'The local repository was not up-to-date:'
    puts pull_results
    puts 'Publish aborted.'

    return false
  end

  return true
end

def push_to_rubygems
  if File.exists?("pkg/fig-#{version}.gem")
    puts "Pushing pkg/fig-#{version}.gem to rubygems.org."
    %x<echo "gem pushe pkg/fig-#{version}.gem">
  end

  return
end

fig_gemspec = Gem::Specification.new do |gemspec|
  gemspec.name = 'fig'
  gemspec.summary = 'Fig is a utility for configuring environments and managing dependencies across a team of developers.'
  gemspec.description = "Fig is a utility for configuring environments and managing dependencies across a team of developers. Given a list of packages and a command to run, Fig builds environment variables named in those packages (e.g., CLASSPATH), then executes the command in that environment. The caller's environment is not affected."
  gemspec.email = 'git@foemmel.com'
  gemspec.homepage = 'http://github.com/mfoemmel/fig'
  gemspec.authors = ['Matthew Foemmel']
  gemspec.platform = Gem::Platform::RUBY
  gemspec.version = version

  gemspec.add_dependency              'sys-admin',         '>= 1.5.6'
  gemspec.add_dependency              'libarchive-static', '>= 1.0.0'
  gemspec.add_dependency              'colorize',          '>= 0.5.8'
  gemspec.add_dependency              'ftp',               '>= 0.69'
  gemspec.add_dependency              'highline',          '>= 1.6.2'
  gemspec.add_dependency              'json',              '>= 1.6.5'
  gemspec.add_dependency              'log4r',             '>= 1.1.5'
  gemspec.add_dependency              'net-netrc',         '>= 0.2.2'
  gemspec.add_dependency              'net-sftp',          '>= 2.0.4'
  gemspec.add_dependency              'net-ssh',           '>= 2.0.15'
  gemspec.add_dependency              'polyglot',          '>= 0.2.9'
  gemspec.add_dependency              'rdoc',              '>= 3.12'
  gemspec.add_dependency              'treetop',           '>= 1.4.2'
  gemspec.add_development_dependency  'open4',             '>= 1.0.1'
  gemspec.add_development_dependency  'rspec',             '>= 2.8'

  gemspec.files = FileList[
    "Changes",
    "VERSION",
    "bin/*",
    "lib/fig/**/*",
  ].to_a

  gemspec.executables = ['fig', 'fig-download']
end

desc 'Run RSpec tests.'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.rspec_opts = []
  spec.rspec_opts << '--order rand'
end

desc 'Increments the major version number by one.'
task :increment_major_version do
    updated_major_version = major_version.to_i + 1
    %x{echo #{updated_major_version}.#{minor_version}.#{patch_version} > 'VERSION'}
end

desc 'Increments the minor version number by one.'
task :increment_minor_version do
    updated_minor_version = minor_version.to_i + 1
    %x{echo #{major_version}.#{updated_minor_version}.#{patch_version} > 'VERSION'}
end

desc 'Increments the patch version number by one.'
task :increment_patch_version do
    updated_patch_version = patch_version.to_i + 1
    %x{echo #{major_version}.#{minor_version}.#{updated_patch_version} > 'VERSION'}
end

Gem::PackageTask.new(fig_gemspec).define

desc 'Alias for the gem task.'
task :build => :gem

desc 'Tag the release, push the tag to the "origin" remote repository, and publish the rubygem to rubygems.org.'
task :publish do
  if local_repo_is_updated?
    if tag_and_push_to_git
      push_to_rubygems
    end
  end
end

task :simplecov do
  ENV['COVERAGE'] = 'true'
  Rake::Task[:spec].invoke
end

task :spec do
  rm_rf './.fig'
end

task :default => :spec

RDoc::Task.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ''

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "fig #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

desc 'Remove build products and temporary files.'
task :clean do
  %w< coverage pkg rdoc resources.tar.gz spec/runtime-work >.each do
    |path|
    rm_rf "./#{path}"
  end
end

desc 'Build and install the Fig gem for local testing.'
task :p do
  sh 'rake build'
  sh 'sudo gem install pkg/*.gem'
end
