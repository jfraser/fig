require 'fig/command/action'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end
class   Fig::Command::Action::ListVariables; end

class Fig::Command::Action::ListVariables::Tree
  include Fig::Command::Action
  def options()
    return %w<--list-variables --list-tree>
  end

  def descriptor_requirement()
    return nil
  end

  def need_base_package?()
    return true
  end

  def need_base_config?()
    return true
  end

  def register_base_package?()
    return false
  end

  def apply_config?()
    return false
  end

  def apply_base_config?()
    return false
  end
end