require 'fig/packagedescriptor'
require 'fig/statement'

module Fig; end

# Dual role: "include :configname" incorporates one configuration into another;
# "include package[/version]" declares a dependency upon another package.
class Fig::Statement::Include < Fig::Statement
  attr_reader :descriptor, :overrides

  def initialize(line_column, descriptor, overrides, containing_package_descriptor)
    super(line_column)

    if descriptor.name && ! descriptor.version
      message =
        %Q<No version in the package descriptor of "#{descriptor.name}" in an include statement>
      if containing_package_descriptor
        message += %Q< in the .fig file for "#{containing_package_descriptor.to_string()}">
      end
      message += '. Whether or not the include statement will work is dependent upon the recursive dependency load order.'

      Fig::Logging.warn(message)
    end

    @descriptor = descriptor
    @overrides = overrides
  end

  def package_name
    return @descriptor.name
  end

  def version
    return @descriptor.version
  end

  def config_name
    return @descriptor.config
  end

  # Assume that this statement is part of the parameter and return a descriptor
  # that represents the fully resolved dependency, taking into account that the
  # version might have been overridden.
  def resolved_dependency_descriptor(containing_package, backtrace)
    return Fig::PackageDescriptor.new(
      referenced_package_name(containing_package),
      referenced_version(containing_package, backtrace),
      referenced_config_name()
    )
  end

  # Block will receive a Package and a Statement.
  def walk_statements_following_package_dependencies(
    repository, package, configuration, &block
  )
    referenced_package = nil
    if package_name()
      referenced_package = repository.get_package(descriptor())
    else
      referenced_package = package
    end

    configuration = referenced_package[referenced_config_name()]

    yield referenced_package, configuration
    configuration.walk_statements_following_package_dependencies(
      repository, referenced_package, nil, &block
    )

    return
  end

  def unparse(indent)
    text = ''
    text += package_name() if package_name()
    text += "/#{version()}" if version()
    text += ":#{config_name()}" if config_name()
    @overrides.each do |override|
      text += override.unparse
    end
    return "#{indent}include #{text}"
  end

  private

  def referenced_package_name(containing_package)
    return package_name() || containing_package.name()
  end

  def referenced_version(containing_package, backtrace)
    overrides().each do
      |override|
      backtrace.add_override(override.package_name(), override.version())
    end

    package_name = nil
    original_version = nil
    if package_name()
      package_name = package_name()
      original_version = version()
    else
      package_name = containing_package.name()
      original_version = containing_package.version()
    end

    return backtrace.get_override(package_name, original_version)
  end

  def referenced_config_name()
    config_name() || Fig::Package::DEFAULT_CONFIG
  end
end
