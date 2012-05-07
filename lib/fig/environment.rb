require 'stringio'

require 'fig/backtrace'
require 'fig/logging'
require 'fig/package'
require 'fig/repositoryerror'
require 'fig/statement/command'
require 'fig/statement/include'
require 'fig/statement/path'
require 'fig/statement/set'
require 'fig/userinputerror'

module Fig; end

# Manages the program's metadata, including packages and environment
# variables, and sets things up for running commands (from "command"
# statements in configuration files).
class Fig::Environment
  # Note: when reading this code, understand that the word "retrieve" is a
  # noun and not a verb, e.g. "retrieve path" means the value of a retrieve
  # and not the action of retrieving a path.

  def initialize(repository, variables_override, working_directory_maintainer)
    @repository = repository
    @variables =
      variables_override || Fig::OperatingSystem.get_environment_variables()
    @retrieves = {}
    @packages = {}
    @working_directory_maintainer = working_directory_maintainer
  end

  # Returns the value of an envirionment variable
  def [](name)
    return @variables[name]
  end

  def variables
    return @variables.clone
  end

  # Indicates that the values from a particular environment variable path
  # should be copied to a local directory.
  def add_retrieve(retrieve_statement)
    name = retrieve_statement.var
    if @retrieves.has_key?(name)
      Fig::Logging.warn \
        %q<About to overwrite "#{name}" retrieve path of "#{@retrieves[name].path}" with "#{retrieve_statement.path}".>
    end

    @retrieves[name] = retrieve_statement
    retrieve_statement.added_to_environment(true)

    return
  end

  def register_package(package)
    name = package.name

    if get_package(name)
      Fig::Logging.fatal %Q<There is already a package with the name "#{name}".>
      raise Fig::RepositoryError.new
    end

    @packages[name] = package

    return
  end

  def get_package(name)
    return @packages[name]
  end

  def packages
    return @packages.values
  end

  def apply_config(package, config_name, backtrace)
    if package.applied_config_names.member?(config_name)
      return
    end
    new_backtrace = backtrace ||
      Fig::Backtrace.new(
        nil,
        Fig::PackageDescriptor.new(package.name, package.version, config_name)
      )

    config = package[config_name]
    config.statements.each do
      |statement|
      apply_config_statement(package, statement, new_backtrace)
    end
    package.add_applied_config_name(config_name)

    return
  end

  def execute_shell(command)
    @variables.with_environment do
      yield command.map{|arg| expand_command_line_argument(arg)}
    end

    return
  end

  def execute_config(base_package, descriptor, args, &block)
    config_name =
      descriptor.config || find_config_name_in_package(descriptor.name)

    name = descriptor.name || base_package.name
    package = lookup_package(
      name,
      descriptor.version,
      Fig::Backtrace.new(
        nil,
        Fig::PackageDescriptor.new(name, descriptor.version, config_name)
      )
    )

    command_statement = package[config_name].command_statement
    if command_statement
      execute_command(command_statement, args, package, &block)
    else
      raise Fig::UserInputError.new(
        %Q<The "#{package.to_s}" package with the "#{config_name}" configuration does not contain a command.>
      )
    end

    return
  end

  # In order for this to work correctly, any Overrides need to be processed
  # before any other kind of Statement.  The Configuration class guarantees
  # that those come first in its set of Statements.
  def apply_config_statement(base_package, statement, backtrace)
    case statement
    when Fig::Statement::Path
      prepend_variable(base_package, statement.name, statement.value)
    when Fig::Statement::Set
      set_variable(base_package, statement.name, statement.value)
    when Fig::Statement::Include
      include_config(base_package, statement.descriptor, backtrace)
    when Fig::Statement::Override
      backtrace.add_override(statement.package_name(), statement.version())
    when Fig::Statement::Command
      # Skip - has no effect on environment.
    else
      raise "Unexpected statement in a config block: #{statement.unparse('')}"
    end

    return
  end

  def include_config(base_package, descriptor, backtrace)
    resolved_descriptor = nil

    # Check to see if this include has been overridden.
    if backtrace
      override = backtrace.get_override(
        descriptor.name || base_package.name
      )
      if override
        resolved_descriptor =
          Fig::PackageDescriptor.new(
            descriptor.name, override, descriptor.config
          )
      end
    end
    resolved_descriptor ||= descriptor

    new_backtrace = Fig::Backtrace.new(backtrace, resolved_descriptor)
    package = lookup_package(
      resolved_descriptor.name || base_package.name,
      resolved_descriptor.version,
      new_backtrace
    )
    apply_config(
      package,
      resolved_descriptor.config || Fig::Package::DEFAULT_CONFIG,
      new_backtrace
    )

    return
  end

  def check_unused_retrieves()
    @retrieves.keys().sort().each do
      |name|

      statement = @retrieves[name]
      if statement.loaded_but_not_referenced?
        Fig::Logging.warn \
          %Q<The #{name} variable was never referenced or didn't need expansion, so "#{statement.unparse('')}"#{statement.position_string} was ignored.>
      end
    end
  end

  private

  def set_variable(base_package, name, value)
    expanded_value =
      expand_variable_as_path_and_process_retrieves(name, value, base_package)
    @variables[name] = expanded_value

    if Fig::Logging.debug?
      expanded_message =
        expanded_value == value ? ''  \
                                : %Q< (expanded from "#{value}")>

      Fig::Logging.debug(
        %Q<Set #{name} to "#{expanded_value}"#{expanded_message}.>
      )
    end

    return
  end

  def prepend_variable(base_package, name, value)
    expanded_value =
      expand_variable_as_path_and_process_retrieves(name, value, base_package)
    @variables.prepend_variable(name, expanded_value)

    if Fig::Logging.debug?
      expanded_message =
        expanded_value == value ? ''  \
                                : %Q< ("#{value}" expanded to "#{expanded_value}")>

      Fig::Logging.debug(
        %Q<Prepending to #{name} resulted in "#{@variables[name]}"#{expanded_message}.>
      )
    end

    return
  end

  def lookup_package(name, version, backtrace)
    package = get_package(name)
    if package.nil?
      if not version
        Fig::Logging.fatal "No version specified for #{name}."
        raise Fig::RepositoryError.new
      end

      package = @repository.get_package(
        Fig::PackageDescriptor.new(name, version, nil)
      )
      package.backtrace = backtrace
      @packages[name] = package
    elsif version && version != package.version
      string_handle = StringIO.new
      backtrace.dump(string_handle) if backtrace
      package.backtrace.dump(string_handle) if package.backtrace
      stacktrace = string_handle.string
      Fig::Logging.fatal                           \
          "Version mismatch: #{name}" \
        + ( stacktrace.empty? ? '' : "\n#{stacktrace}" )
      raise Fig::RepositoryError.new
    end

    return package
  end

  def find_config_name_in_package(name)
    package = get_package(name)
    if not package
      return Fig::Package::DEFAULT_CONFIG
    end

    return package.primary_config_name || Fig::Package::DEFAULT_CONFIG
  end

  def execute_command(command_statement, args, package)
    @variables.with_environment do
      argument =
        expand_command_line_argument(
          "#{command_statement.command} #{args.join(' ')}"
        )

      yield expand_at_signs_in_path(argument, package).split(' ')
    end

    return
  end

  def expand_variable_as_path_and_process_retrieves(
    variable_name, variable_value, base_package
  )
    return variable_value unless base_package && base_package.name

    variable_value = expand_at_signs_in_path(variable_value, base_package)

    return variable_value if not @retrieves.member?(variable_name)

    return retrieve_files(variable_name, variable_value, base_package)
  end

  def retrieve_files(variable_name, variable_value, base_package)
    check_source_existence(variable_name, variable_value, base_package)

    destination_path = nil

    # A '//' in the variable value tells us to preserve path
    # information after the '//' when doing a retrieve.
    if variable_value.split('//').size > 1
      preserved_path = variable_value.split('//').last
      destination_path = File.join(
        get_retrieve_path_with_substitution(variable_name, base_package),
        preserved_path
      )
    else
      destination_path =
        get_retrieve_path_with_substitution(variable_name, base_package)
      if not File.directory?(variable_value)
        destination_path =
          File.join(destination_path, File.basename(variable_value))
      end
    end

    @working_directory_maintainer.with_package_version(
      base_package.name, base_package.version
    ) do
      @working_directory_maintainer.retrieve(variable_value, destination_path)
    end

    return destination_path
  end

  def check_source_existence(variable_name, variable_value, base_package)
    return if File.exists?(variable_value) || File.symlink?(variable_value)

    Fig::Logging.fatal(
      %Q<In #{base_package}, the #{variable_name} variable points to a path that does not exist ("#{variable_value}", after expansion).>
    )
    raise Fig::RepositoryError.new
  end

  def expand_at_signs_in_path(path, base_package)
    expanded_path =
      replace_at_signs_with_package_references(path, base_package)
    check_for_bad_escape(expanded_path, path)

    return collapse_backslashes_for_escaped_at_signs(expanded_path)
  end

  def replace_at_signs_with_package_references(arg, base_package)
    return arg.gsub(
      %r<
        (?: ^ | \G)           # Zero-width anchor.
        ( [^\\@]* (?:\\{2})*) # An even number of leading backslashes
        \@                    # The package indicator
      >x
    ) do |match|
      backslashes = $1 || ''
      backslashes + base_package.directory
    end
  end

  def expand_command_line_argument(arg)
    package_substituted = expand_named_package_references(arg)
    check_for_bad_escape(package_substituted, arg)

    return collapse_backslashes_for_escaped_at_signs(package_substituted)
  end

  def expand_named_package_references(arg)
    return arg.gsub(
      # TODO: Refactor package name regex into PackageDescriptor constant.
      %r<
        (?: ^ | \G)           # Zero-width anchor.
        ( [^\\@]* (?:\\{2})*) # An even number of leading backslashes
        \@                    # The package indicator
        ( [a-zA-Z0-9_.-]+ )   # Package name
      >x
    ) do |match|
      backslashes = $1 || ''
      package_name = $2
      package = get_package(package_name)
      if package.nil?
        raise Fig::RepositoryError.new(
          %Q<Command-line referenced the "#{package_name}" package, which has not been referenced by any other package.>
        )
      end
      backslashes + package.directory
    end
  end

  # The value is expected to have had any @ substitution already done, but
  # collapsing of escapes not done yet.
  def check_for_bad_escape(substituted, original)
    if substituted =~ %r<
      (?: ^ | [^\\])  # Start of line or non backslash
      (?: \\{2})*     # Even number of backslashes (including zero)
      ( \\ [^\\@] )   # A bad escape
    >x
      raise Fig::RepositoryError.new(
        %Q<Unknown escape "#{$1}" in "#{original}">
      )
    end

    return
  end

  # After @ substitution, we need to get rid of the backslashes in front of
  # any escaped @ signs.
  def collapse_backslashes_for_escaped_at_signs(string)
    return string.gsub(%r< \\ ([\\@]) >x, '\1')
  end

  def get_retrieve_path_with_substitution(name, base_package)
    retrieve_statement = @retrieves[name]
    retrieve_statement.referenced(true)

    return retrieve_statement.path.gsub(/ \[package\] /x, base_package.name)
  end
end
