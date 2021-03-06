require 'fig/command/action'
require 'fig/command/action/role/has_no_sub_action'
require 'fig/command/action/role/update'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end

class Fig::Command::Action::Update
  include Fig::Command::Action
  include Fig::Command::Action::Role::HasNoSubAction
  include Fig::Command::Action::Role::Update

  def options()
    return %w<--update>
  end

  def prepare_repository(repository)
    repository.update_unconditionally

    return
  end
end
