require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

require 'English'

require 'fig/command/package_loader'

def set_up_local_and_remote_repository
  cleanup_home_and_remote

  input = <<-END_INPUT
    config default
      set FOO=BAR
    end

    config nondefault
      set FOO=BAZ
    end
  END_INPUT
  fig(%w<--publish prerequisite/1.2.3>, input)

  input = <<-END_INPUT
    config default
      include prerequisite/1.2.3
      set FOO=BAR
    end

    config nondefault
      include prerequisite/1.2.3
      set FOO=BAZ
    end
  END_INPUT

  fig(%w<--publish remote-only/1.2.3>, input)
  fig(%w<--clean remote-only/1.2.3>)
  fig(%w<--publish both/1.2.3>, input)
  fig(%w<--publish-local local-only/1.2.3>, input)

  return
end

def set_up_local_and_remote_repository_with_depends_on_everything
  set_up_local_and_remote_repository

  input = <<-END_INPUT
    config default
      include :everything
    end

    config everything
      include prerequisite/1.2.3
      include local-only/1.2.3
      include remote-only/1.2.3
      include both/1.2.3
    end
  END_INPUT

  fig(%w<--publish depends-on-everything/1.2.3>, input)

  input = <<-END_INPUT
    config default
    end

    config indirectly-everything
      include depends-on-everything/1.2.3:everything
    end
  END_INPUT

  fig(%w<--publish depends-on-depends-on-everything/1.2.3>, input)
  fig(
    %w<
      --update-if-missing
      --include depends-on-depends-on-everything/1.2.3:indirectly-everything
    >,
    input
  )

  return
end

def set_up_multiple_config_repository
  cleanup_home_and_remote

  # Note: make sure that configs within each package are NOT in sorted order.
  # Part of the output testing is ordering.

  input = <<-END_INPUT
    config default
    end
  END_INPUT
  fig(%w<--publish no-dependencies/1.2.3>, input)

  # Configs in "--publish"es below are required because there is no "default"
  # config in the packages.

  input = <<-END_INPUT
    config windows
      set OS=Windows
    end

    config ubuntu
      set OS=Linux
    end

    config redhat
      set OS=Linux
    end

    config unreferenced
      include this-should-not-show-up-in-any-output/45
    end
  END_INPUT
  fig(%w<--publish operatingsystem/1.2.3:windows>, input)

  # Ensure we have a case where two different configs' dependencies conflict.
  fig(%w<--publish operatingsystem/3.4.5:redhat>, input)

  input = <<-END_INPUT
    config oracle
      include operatingsystem/1.2.3:redhat
    end

    config postgresql
      include operatingsystem/3.4.5:ubuntu
    end

    config sqlserver
      include operatingsystem/1.2.3:windows
    end

    config unreferenced
      include this-should-not-show-up-in-any-output/942.29024.2939.209.1
    end

    config mysql
      include operatingsystem/1.2.3:ubuntu
    end
  END_INPUT
  fig(%w<--publish database/1.2.3:oracle>, input)

  input = <<-END_INPUT
    config apache
      include operatingsystem/1.2.3:redhat
    end

    config iis
      include operatingsystem/1.2.3:windows
    end

    config unreferenced
      include this-should-not-show-up-in-any-output/23.123.63.23
    end

    config lighttpd
      include operatingsystem/3.4.5:ubuntu
    end
  END_INPUT
  fig(%w<--publish web/1.2.3:apache>, input)

  input = <<-END_INPUT
    config accounting
      include database/1.2.3:oracle
      include web/1.2.3:apache
    end

    config facilities
      include web/1.2.3:lighttpd
      include database/1.2.3:mysql
    end

    config marketing
      include database/1.2.3:postgresql
      include web/1.2.3:lighttpd
    end

    config legal
      include web/1.2.3:iis
      include database/1.2.3:sqlserver
    end
  END_INPUT
  fig(%w<--publish departments/1.2.3:accounting>, input)

  return
end

def create_package_dot_fig(package_name, config = nil)
  config = config ? config = ':' + config : ''

  File.open "#{CURRENT_DIRECTORY}/#{Fig::Command::PackageLoader::DEFAULT_FIG_FILE}", 'w' do
    |handle|
    handle.print <<-END
      config default
        include #{package_name}/1.2.3#{config}
      end
    END
  end

  return
end

def create_package_dot_fig_with_single_dependency()
  create_package_dot_fig('prerequisite')
end

def create_package_dot_fig_with_all_dependencies()
  create_package_dot_fig(
    'depends-on-everything', Fig::Package::DEFAULT_CONFIG
  )
end

def set_up_list_variables_packages
  cleanup_home_and_remote

  input_a = <<-END_INPUT
    config default
      set A_BOTH_CONFIGS=default
      set A_DEFAULT=BAR
      set D_OVERRIDES_A=A
      set B_OVERRIDES_A_AND_C=A
      append A_PATH_DEFAULT=BAR
      append D_PATH_PREPENDS_A=A
      append B_PATH_PREPENDS_A_AND_C=A
      set A_SET_GETS_PREPENDED_WITH_B_AND_C=A

      # Note includes are not in alphabetical order in order to check that
      # sorting does or does not happen.
      include C/1.2.3
      include B/1.2.3

      set A_OVERRIDES_C_PREPENDING_B=A

      set A_OVERRIDES_B_AND_C=A
      set A_OVERRIDES_D=A
      append A_PATH_PREPENDS_B_AND_C=A
      append A_PATH_PREPENDS_D=A
    end

    config nondefault
      set A_BOTH_CONFIGS=nondefault
      set A_NONDEFAULT=BAZ

      include C/4.5.6:nondefault
    end
  END_INPUT

  input_b = <<-END_INPUT
    config default
      set B_DEFAULT=BAR
      set B_OVERRIDES_C=B
      set B_OVERRIDES_A_AND_C=B
      set A_OVERRIDES_B_AND_C=B
      append B_PATH_PREPENDS_A_AND_C=B
      append A_PATH_PREPENDS_B_AND_C=B
      append A_SET_GETS_PREPENDED_WITH_B_AND_C=B
      append A_OVERRIDES_C_PREPENDING_B=B

      # Note lack of version.  That this works depends upon another include of
      # D to be encountered during parse to include the version.
      include D
    end

    config nondefault
      set B_NONDEFAULT=BAZ
    end

    config should_not_show_up_in_output
      set SHOULD_NOT_SHOW_UP_IN_OUTPUT_FROM_B=should_not_show_up
    end
  END_INPUT

  input_c123 = <<-END_INPUT
    config default
      set C_DEFAULT=BAR
      set B_OVERRIDES_C=C
      set B_OVERRIDES_A_AND_C=C
      set A_OVERRIDES_B_AND_C=C
      append B_PATH_PREPENDS_A_AND_C=C
      append A_PATH_PREPENDS_B_AND_C=C
      append A_SET_GETS_PREPENDED_WITH_B_AND_C=C
      append A_OVERRIDES_C_PREPENDING_B=C

      include D/1.2.3
    end

    config nondefault
      set C_NONDEFAULT=BAZ
    end

    config should_not_show_up_in_output
      set SHOULD_NOT_SHOW_UP_IN_OUTPUT_FROM_C=should_not_show_up
    end
  END_INPUT

  input_c456 = <<-END_INPUT
    config default
      set C_DEFAULT=BAR
      set C_OVERRIDES_B=C
      set C_OVERRIDES_A_AND_B=C
      set A_OVERRIDES_B_AND_C=C
      append A_PATH_PREPENDS_B_AND_C=C
      append A_SET_GETS_PREPENDED_WITH_B_AND_C=C
      append A_OVERRIDES_C_PREPENDING_B=C

      include D/1.2.3
    end

    config nondefault
      set C_ONLY_IN_C456=C
    end

    config should_not_show_up_in_output
      set SHOULD_NOT_SHOW_UP_IN_OUTPUT_FROM_C=should_not_show_up
    end
  END_INPUT

  input_d = <<-END_INPUT
    config default
      set D_DEFAULT=BAR
      set A_OVERRIDES_D=D
      set D_OVERRIDES_A=D
      append D_PATH_PREPENDS_A=D
      append A_PATH_PREPENDS_D=D

      include :addon_a
      include :addon_b
      include :addon_c
    end

    config addon_a
      set ADDON_A=ding
    end

    config addon_b
      set ADDON_B=dong

      include E/1.2.3
    end

    config addon_c
      set ADDON_C=dang
    end

    config nondefault
      set D_NONDEFAULT=BAZ
    end

    config should_not_show_up_in_output
      set SHOULD_NOT_SHOW_UP_IN_OUTPUT_FROM_D=should_not_show_up
    end
  END_INPUT

  input_e = <<-END_INPUT
    config default
    end
  END_INPUT

  fig(%w<--publish E/1.2.3>, input_e)
  fig(%w<--publish D/1.2.3>, input_d)
  fig(%w<--publish C/1.2.3>, input_c123)
  fig(%w<--publish C/4.5.6>, input_c456)

  # Use non-default config to avoid issue with "include D" without a version.
  fig(%w<--publish B/1.2.3:nondefault>, input_b)

  fig(%w<--publish A/1.2.3>, input_a)
end

def set_up_packages_with_overrides
  cleanup_home_and_remote

  input_a = <<-END_INPUT
    config default
      include B/1.2.3 override C/4.5.6 override D/4.5.6
    end
  END_INPUT

  input_b = <<-END_INPUT
    config default
      include C/1.2.3
      include D/1.2.3
    end
  END_INPUT

  input_c123 = <<-END_INPUT
    config default
      set C=1.2.3

      include D/1.2.3
    end
  END_INPUT

  input_c456 = <<-END_INPUT
    config default
      set C=4.5.6

      include D/1.2.3
    end
  END_INPUT

  input_d = <<-END_INPUT
    config default
    end
  END_INPUT

  fig(%w<--publish D/1.2.3>, input_d)
  fig(%w<--publish D/4.5.6>, input_d)
  fig(%w<--publish C/1.2.3>, input_c123)
  fig(%w<--publish C/4.5.6>, input_c456)
  fig(%w<--publish B/1.2.3>, input_b)
  fig(%w<--publish A/1.2.3>, input_a)
end

def remove_any_package_dot_fig
  FileUtils.rm_rf "#{CURRENT_DIRECTORY}/#{Fig::Command::PackageLoader::DEFAULT_FIG_FILE}"

  return
end

def test_list_configs(package_name)
  set_up_local_and_remote_repository

  out, err = fig(['--list-configs', "#{package_name}/1.2.3"])
  out.should == "default\nnondefault"
  err.should == ''

  return
end

# Allow for indenting in expected output given in heredocs.
def clean_expected(expected)
  cleaned = expected.chomp

  indent_count = cleaned.scan(/ ^ [ ]+ /x).collect(&:length).min
  cleaned.gsub!(/ ^ [ ]{#{indent_count}} /x, '')

  return cleaned
end

describe 'Fig' do
  describe '--list-local' do
    before(:each) do
      clean_up_test_environment
      set_up_test_environment
    end

    it %q<prints nothing with an empty repository> do
      out, err = fig(%w<--list-local>)
      out.should == ''
      err.should == ''
    end

    it %q<prints only local packages> do
      set_up_local_and_remote_repository

      out, err = fig(%w<--list-local>)
      out.should == "both/1.2.3\nlocal-only/1.2.3\nprerequisite/1.2.3"
      err.should == ''
    end

    it 'should complain if with a package descriptor' do
      out, err, exit_code = fig(%w<--list-local foo>, :no_raise_on_error => true)
      out.should     be_empty
      err.should_not be_empty
      exit_code.should_not == 0
    end

    it %q<should complain if local repository isn't in the expected format version> do
      set_local_repository_format_to_future_version()

      out, err, exit_code = fig(%w<--list-local>, :no_raise_on_error => true)
      err.should =~
        /Local repository is in version \d+ format. This version of fig can only deal with repositories in version \d+ format\./
      exit_code.should_not == 0
    end
  end

  describe '--list-remote' do
    before(:each) do
      clean_up_test_environment
      set_up_test_environment
    end

    it %q<prints nothing with an empty repository> do
      out, err = fig(%w<--list-remote>)
      out.should == ''
      err.should == ''
    end

    it %q<prints only remote packages> do
      set_up_local_and_remote_repository

      out, err = fig(%w<--list-remote>)
      out.should == "both/1.2.3\nprerequisite/1.2.3\nremote-only/1.2.3"
      err.should == ''
    end

    it 'should complain if with a package descriptor' do
      out, err, exit_code =
        fig(%w<--list-remote foo>, :no_raise_on_error => true)
      err.should_not be_empty
      exit_code.should_not == 0
    end

    it %q<should complain if remote repository isn't in the expected format version> do
      set_remote_repository_format_to_future_version()

      out, err, exit_code = fig(%w<--list-remote>, :no_raise_on_error => true)
      err.should =~
        /Remote repository is in version \d+ format. This version of fig can only deal with repositories in version \d+ format\./
      exit_code.should_not == 0
    end
  end

  describe '--list-configs' do
    before(:each) do
      clean_up_test_environment
      set_up_test_environment
    end

    it %q<prints all the configurations for local-only> do
      test_list_configs('local-only')
    end

    it %q<prints all the configurations for both> do
      test_list_configs('both')
    end

    it %q<prints all the configurations for remote-only> do
      set_up_local_and_remote_repository

      out, err, exit_code =
        fig(%w<--list-configs remote-only/1.2.3>, :no_raise_on_error => true)
      exit_code.should_not == 0
      err.should =~ /Fig file not found for package/
    end
  end

  describe '--list-dependencies' do
    before(:each) do
      clean_up_test_environment
      set_up_test_environment
      cleanup_home_and_remote
    end

    describe 'no --list-tree' do
      describe 'no --list-all-configs' do
        it %q<lists nothing when there are no dependencies without a package.fig (and output is not a tty)> do
          set_up_local_and_remote_repository_with_depends_on_everything
          remove_any_package_dot_fig

          out, err = fig(%w<--list-dependencies prerequisite/1.2.3>)
          out.should == ''
          err.should == ''
        end

        it %q<lists only the single dependency and not all in the repository with a package.fig> do
          set_up_local_and_remote_repository_with_depends_on_everything
          create_package_dot_fig_with_single_dependency

          out, err = fig(%w<--list-dependencies>)
          out.should == 'prerequisite/1.2.3'
          err.should == ''
        end

        it %q<lists almost all packages in the repository without a package.fig> do
          set_up_local_and_remote_repository_with_depends_on_everything
          remove_any_package_dot_fig

          expected = clean_expected(<<-END_EXPECTED_OUTPUT)
            both/1.2.3
            depends-on-everything/1.2.3
            local-only/1.2.3
            prerequisite/1.2.3
            remote-only/1.2.3
          END_EXPECTED_OUTPUT

          out, err = fig(
            %w<
              --list-dependencies
              depends-on-depends-on-everything/1.2.3:indirectly-everything
            >
          )
          out.should == expected
          err.should == ''
        end

        it %q<lists all packages in the repository with a package.fig> do
          set_up_local_and_remote_repository_with_depends_on_everything
          create_package_dot_fig_with_all_dependencies

          expected = clean_expected(<<-END_EXPECTED_OUTPUT)
            both/1.2.3
            depends-on-everything/1.2.3
            local-only/1.2.3
            prerequisite/1.2.3
            remote-only/1.2.3
          END_EXPECTED_OUTPUT

          out, err = fig(%w<--list-dependencies>)
          out.should == expected
          err.should == ''
        end
      end

      describe 'with --list-all-configs' do
        it %q<lists only the single configuration when there are no dependencies without a package.fig> do
          set_up_multiple_config_repository
          remove_any_package_dot_fig

          expected = clean_expected(<<-END_EXPECTED_OUTPUT)
            no-dependencies/1.2.3
          END_EXPECTED_OUTPUT

          out, err = fig(
            %w<--list-dependencies --list-all-configs no-dependencies/1.2.3>
          )
          out.should == expected
          err.should == ''
        end

        it %q<lists only the single dependency and not all in the repository with a package.fig> do
          set_up_multiple_config_repository
          create_package_dot_fig('no-dependencies')

          expected = clean_expected(<<-END_EXPECTED_OUTPUT)
            no-dependencies/1.2.3
          END_EXPECTED_OUTPUT

          out, err = fig(%w<--list-dependencies --list-all-configs>)
          out.should == expected
          err.should == ''
        end

        it %q<lists all recursive configuration dependencies without a package.fig> do
          set_up_multiple_config_repository
          remove_any_package_dot_fig

          expected = clean_expected(<<-END_EXPECTED_OUTPUT)
            database/1.2.3:mysql
            database/1.2.3:oracle
            database/1.2.3:postgresql
            database/1.2.3:sqlserver
            departments/1.2.3:accounting
            departments/1.2.3:facilities
            departments/1.2.3:legal
            departments/1.2.3:marketing
            operatingsystem/1.2.3:redhat
            operatingsystem/1.2.3:ubuntu
            operatingsystem/1.2.3:windows
            operatingsystem/3.4.5:ubuntu
            web/1.2.3:apache
            web/1.2.3:iis
            web/1.2.3:lighttpd
          END_EXPECTED_OUTPUT

          out, err = fig(
            %w<--list-dependencies --list-all-configs departments/1.2.3:legal>
          )
          out.should == expected
          err.should == ''
        end

        it %q<lists all packages in the repository with a package.fig> do
          set_up_local_and_remote_repository_with_depends_on_everything
          create_package_dot_fig_with_all_dependencies

          expected = clean_expected(<<-END_EXPECTED_OUTPUT)
            both/1.2.3
            depends-on-everything/1.2.3
            depends-on-everything/1.2.3:everything
            local-only/1.2.3
            prerequisite/1.2.3
            remote-only/1.2.3
          END_EXPECTED_OUTPUT

          out, err = fig(%w<--list-dependencies --list-all-configs>)
          out.should == expected
          err.should == ''
        end
      end
    end

    describe 'with --list-tree' do
      describe 'no --list-all-configs' do
        it %q<lists the package when there are no dependencies without a package.fig (and output is not a tty)> do
          set_up_local_and_remote_repository_with_depends_on_everything
          remove_any_package_dot_fig

          out, err =
            fig(%w<--list-dependencies --list-tree prerequisite/1.2.3>)
          out.should == 'prerequisite/1.2.3'
          err.should == ''
        end

        it %q<lists only the package and the dependency and not all in the repository with a package.fig> do
          set_up_local_and_remote_repository_with_depends_on_everything
          create_package_dot_fig_with_single_dependency

          expected = clean_expected(<<-END_EXPECTED_OUTPUT)
            <unpublished>
                prerequisite/1.2.3
          END_EXPECTED_OUTPUT

          out, err = fig(%w<--list-dependencies --list-tree>)
          out.should == expected
          err.should == ''
        end

        it %q<lists almost all packages in the repository without a package.fig> do
          set_up_local_and_remote_repository_with_depends_on_everything
          remove_any_package_dot_fig

          expected = clean_expected(<<-END_EXPECTED_OUTPUT)
            depends-on-depends-on-everything/1.2.3:indirectly-everything
                depends-on-everything/1.2.3:everything
                    prerequisite/1.2.3
                    local-only/1.2.3
                        prerequisite/1.2.3
                    remote-only/1.2.3
                        prerequisite/1.2.3
                    both/1.2.3
                        prerequisite/1.2.3
          END_EXPECTED_OUTPUT

          out, err = fig(
            %w<
              --list-dependencies
              --list-tree depends-on-depends-on-everything/1.2.3:indirectly-everything
            >
          )
          out.should == expected
          err.should == ''
        end

        it %q<lists all packages in the repository with a package.fig> do
          set_up_local_and_remote_repository_with_depends_on_everything
          create_package_dot_fig_with_all_dependencies

          expected = clean_expected(<<-END_EXPECTED_OUTPUT)
            <unpublished>
                depends-on-everything/1.2.3
                    depends-on-everything/1.2.3:everything
                        prerequisite/1.2.3
                        local-only/1.2.3
                            prerequisite/1.2.3
                        remote-only/1.2.3
                            prerequisite/1.2.3
                        both/1.2.3
                            prerequisite/1.2.3
          END_EXPECTED_OUTPUT

          out, err = fig(%w<--list-dependencies --list-tree>)
          out.should == expected
          err.should == ''
        end
      end

      describe 'with --list-all-configs' do
        it %q<lists only the single configuration when there are no dependencies without a package.fig> do
          set_up_multiple_config_repository
          remove_any_package_dot_fig

          expected = clean_expected(<<-END_EXPECTED_OUTPUT)
            no-dependencies/1.2.3
          END_EXPECTED_OUTPUT

          out, err = fig(
            %w<
              --list-dependencies --list-tree --list-all-configs
              no-dependencies/1.2.3
            >
          )
          out.should == expected
          err.should == ''
        end

        it %q<lists only the package and the dependency and not all in the repository with a package.fig> do
          set_up_multiple_config_repository
          create_package_dot_fig('no-dependencies')

          expected = clean_expected(<<-END_EXPECTED_OUTPUT)
            <unpublished>
                no-dependencies/1.2.3
          END_EXPECTED_OUTPUT

          out, err =
            fig(%w<--list-dependencies --list-tree --list-all-configs>)
          out.should == expected
          err.should == ''
        end

        it %q<lists almost all packages in the repository without a package.fig> do
          set_up_multiple_config_repository
          remove_any_package_dot_fig

          expected = clean_expected(<<-END_EXPECTED_OUTPUT)
            departments/1.2.3:accounting
                database/1.2.3:oracle
                    operatingsystem/1.2.3:redhat
                web/1.2.3:apache
                    operatingsystem/1.2.3:redhat
            departments/1.2.3:facilities
                web/1.2.3:lighttpd
                    operatingsystem/3.4.5:ubuntu
                database/1.2.3:mysql
                    operatingsystem/1.2.3:ubuntu
            departments/1.2.3:marketing
                database/1.2.3:postgresql
                    operatingsystem/3.4.5:ubuntu
                web/1.2.3:lighttpd
                    operatingsystem/3.4.5:ubuntu
            departments/1.2.3:legal
                web/1.2.3:iis
                    operatingsystem/1.2.3:windows
                database/1.2.3:sqlserver
                    operatingsystem/1.2.3:windows
          END_EXPECTED_OUTPUT

          out, err = fig(
            %w<
              --list-dependencies --list-tree --list-all-configs
              departments/1.2.3
            >
          )
          out.should == expected
          err.should == ''
        end

        it %q<lists only the configs in a package.fig and not all configs in dependencies> do
          set_up_multiple_config_repository

          File.open "#{CURRENT_DIRECTORY}/#{Fig::Command::PackageLoader::DEFAULT_FIG_FILE}", 'w' do
            |handle|
            handle.print <<-END
              config machineA
                include departments/1.2.3:marketing
                include departments/1.2.3:legal
              end

              config machineB
                include departments/1.2.3:facilities
              end
            END
          end

          expected = clean_expected(<<-END_EXPECTED_OUTPUT)
            <unpublished>:machineA
                departments/1.2.3:marketing
                    database/1.2.3:postgresql
                        operatingsystem/3.4.5:ubuntu
                    web/1.2.3:lighttpd
                        operatingsystem/3.4.5:ubuntu
                departments/1.2.3:legal
                    web/1.2.3:iis
                        operatingsystem/1.2.3:windows
                    database/1.2.3:sqlserver
                        operatingsystem/1.2.3:windows
            <unpublished>:machineB
                departments/1.2.3:facilities
                    web/1.2.3:lighttpd
                        operatingsystem/3.4.5:ubuntu
                    database/1.2.3:mysql
                        operatingsystem/1.2.3:ubuntu
          END_EXPECTED_OUTPUT

          out, err =
            fig(%w<--list-dependencies --list-tree --list-all-configs>)
          out.should == expected
          err.should == ''
        end

        it %q<handles the case where a specific config may pick up a different dependency version depending upon the order in which it was reached.> do
          input_downstream = <<-END_INPUT
            # This path should work because there's a version of upstream
            # specified.
            config default
              include :include-upstream override upstream/standard
            end

            # This path should fail because there's no version of upstream
            # specified despite the fact that the walk of this file will end up
            # with the default config being hit before this one.
            config nondefault
              include :include-upstream
            end

            config include-upstream
              include upstream
            end
          END_INPUT

          input_upstream = <<-END_INPUT
            config default
            end
          END_INPUT

          fig(%w<--publish upstream/standard>, input_upstream)
          fig(%w<--publish upstream/non-standard>, input_upstream)

          fig(%w<--publish downstream/whatever>, input_downstream)

          expected = clean_expected(<<-END_EXPECTED_OUTPUT)
            downstream/whatever
                downstream/whatever:include-upstream
                    upstream/standard
            downstream/whatever:nondefault
                downstream/whatever:include-upstream
          END_EXPECTED_OUTPUT

          out, err, exit_code = fig(
            %w<
              --list-dependencies --list-tree --list-all-configs
              downstream/whatever
            >,
            :no_raise_on_error => true
          )
          out.should == expected
          err.should =~ /Cannot retrieve "upstream" without a version/
          exit_code.should_not == 0
        end
      end
    end

    it %q<handles "include ... override ..."> do
      set_up_packages_with_overrides
      remove_any_package_dot_fig

      expected = clean_expected(<<-END_EXPECTED_OUTPUT)
        B/1.2.3
        C/4.5.6
        D/4.5.6
      END_EXPECTED_OUTPUT

      out, err = fig(%w<--list-dependencies A/1.2.3>)
      out.should == expected
      err.should == ''
    end

    it %q<handles --config> do
      input_prerequisite = <<-END_INPUT
        config default
        end
      END_INPUT

      fig(%w<--publish prerequisite/1.2.3>, input_prerequisite)

      File.open "#{CURRENT_DIRECTORY}/#{Fig::Command::PackageLoader::DEFAULT_FIG_FILE}", 'w' do
        |handle|
        handle.print <<-END
          config default
            # No version, which would cause load to fail if it is hit first.
            include prerequisite
          end

          config nondefault
            include prerequisite/1.2.3
            include :default
          end
        END
      end

      expected = clean_expected(<<-END_EXPECTED_OUTPUT)
        prerequisite/1.2.3
      END_EXPECTED_OUTPUT

      out, err = fig(%w<--list-dependencies --config nondefault>)
      out.should == expected
      err.should =~ /No version in the package descriptor of "prerequisite" in an include statement/
    end

    it %q<should complain if local repository isn't in the expected format version> do
      set_up_packages_with_overrides
      remove_any_package_dot_fig
      set_local_repository_format_to_future_version

      out, err, exit_code =
        fig(%w<--list-dependencies A/1.2.3>, :no_raise_on_error => true)
      exit_code.should_not == 0
      err.should =~
        /Local repository is in version \d+ format. This version of fig can only deal with repositories in version \d+ format\./
    end
  end

  describe '--list-variables' do
    describe 'no --list-tree' do
      describe 'no --list-all-configs' do
        before(:each) do
          clean_up_test_environment
          set_up_test_environment
        end

        it %q<lists no dependency variables when none should exist without a package.fig> do
          set_up_list_variables_packages
          out, err = fig(%w<--list-variables E/1.2.3>)
          out.should == ''
          err.should == ''
        end

        it %q<lists no dependency variables when none should exist with a package.fig> do
          set_up_list_variables_packages
          create_package_dot_fig('E')
          out, err = fig(%w<--list-variables>)
          out.should == ''
          err.should == ''
        end

        it %q<lists all dependency variables without a package.fig> do
          set_up_list_variables_packages

          expected = clean_expected(<<-END_EXPECTED_OUTPUT)
            ADDON_A=ding
            ADDON_B=dong
            ADDON_C=dang
            A_BOTH_CONFIGS=default
            A_DEFAULT=BAR
            A_OVERRIDES_B_AND_C=A
            A_OVERRIDES_C_PREPENDING_B=A
            A_OVERRIDES_D=A
            A_PATH_DEFAULT=BAR
            A_PATH_PREPENDS_B_AND_C=A:B:C
            A_PATH_PREPENDS_D=A:D
            A_SET_GETS_PREPENDED_WITH_B_AND_C=B:C:A
            B_DEFAULT=BAR
            B_OVERRIDES_A_AND_C=B
            B_OVERRIDES_C=B
            B_PATH_PREPENDS_A_AND_C=B:C:A
            C_DEFAULT=BAR
            D_DEFAULT=BAR
            D_OVERRIDES_A=D
            D_PATH_PREPENDS_A=D:A
          END_EXPECTED_OUTPUT

          expected.gsub!(/:/,File::PATH_SEPARATOR)

          out, err = fig(%w<--list-variables A/1.2.3>)
          out.should == expected
          err.should =~
            %r<No version in the package descriptor of "D" in an include statement in the \.fig file for "B/1\.2\.3" \(line>
        end

        it %q<lists all dependency variables with a package.fig> do
          set_up_list_variables_packages
          create_package_dot_fig('A')

          expected = clean_expected(<<-END_EXPECTED_OUTPUT)
            ADDON_A=ding
            ADDON_B=dong
            ADDON_C=dang
            A_BOTH_CONFIGS=default
            A_DEFAULT=BAR
            A_OVERRIDES_B_AND_C=A
            A_OVERRIDES_C_PREPENDING_B=A
            A_OVERRIDES_D=A
            A_PATH_DEFAULT=BAR
            A_PATH_PREPENDS_B_AND_C=A:B:C
            A_PATH_PREPENDS_D=A:D
            A_SET_GETS_PREPENDED_WITH_B_AND_C=B:C:A
            B_DEFAULT=BAR
            B_OVERRIDES_A_AND_C=B
            B_OVERRIDES_C=B
            B_PATH_PREPENDS_A_AND_C=B:C:A
            C_DEFAULT=BAR
            D_DEFAULT=BAR
            D_OVERRIDES_A=D
            D_PATH_PREPENDS_A=D:A
          END_EXPECTED_OUTPUT

          expected.gsub!(/:/,File::PATH_SEPARATOR)

          out, err = fig(%w<--list-variables>)

          out.should == expected
          err.should =~
            %r<No version in the package descriptor of "D" in an include statement in the \.fig file for "B/1\.2\.3" \(line>
        end
      end

      describe 'with --list-all-configs' do
        before(:each) do
          clean_up_test_environment
          set_up_test_environment
        end

        it %q<lists no dependency variables when none should exist without a package.fig> do
          set_up_list_variables_packages
          out, err = fig(%w<--list-variables --list-all-configs E/1.2.3>)
          out.should == ''
          err.should == ''
        end

        it %q<lists no dependency variables when none should exist with a package.fig> do
          set_up_list_variables_packages
          create_package_dot_fig('E')
          out, err = fig(%w<--list-variables --list-all-configs>)
          out.should == ''
          err.should == ''
        end

        it %q<lists all dependency variables without a package.fig> do
          set_up_list_variables_packages

          expected = clean_expected(<<-END_EXPECTED_OUTPUT)
            ADDON_A
            ADDON_B
            ADDON_C
            A_BOTH_CONFIGS
            A_DEFAULT
            A_NONDEFAULT
            A_OVERRIDES_B_AND_C
            A_OVERRIDES_C_PREPENDING_B
            A_OVERRIDES_D
            A_PATH_DEFAULT
            A_PATH_PREPENDS_B_AND_C
            A_PATH_PREPENDS_D
            A_SET_GETS_PREPENDED_WITH_B_AND_C
            B_DEFAULT
            B_OVERRIDES_A_AND_C
            B_OVERRIDES_C
            B_PATH_PREPENDS_A_AND_C
            C_DEFAULT
            C_ONLY_IN_C456
            D_DEFAULT
            D_OVERRIDES_A
            D_PATH_PREPENDS_A
          END_EXPECTED_OUTPUT

          expected.gsub!(/:/,File::PATH_SEPARATOR)

          out, err = fig(%w<--list-variables --list-all-configs A/1.2.3>)
          out.should == expected
          err.should =~
            %r<No version in the package descriptor of "D" in an include statement in the \.fig file for "B/1\.2\.3:default" \(line>
        end

        it %q<lists all dependency variables with a package.fig> do
          set_up_list_variables_packages
          create_package_dot_fig('A')

          expected = clean_expected(<<-END_EXPECTED_OUTPUT)
            ADDON_A
            ADDON_B
            ADDON_C
            A_BOTH_CONFIGS
            A_DEFAULT
            A_OVERRIDES_B_AND_C
            A_OVERRIDES_C_PREPENDING_B
            A_OVERRIDES_D
            A_PATH_DEFAULT
            A_PATH_PREPENDS_B_AND_C
            A_PATH_PREPENDS_D
            A_SET_GETS_PREPENDED_WITH_B_AND_C
            B_DEFAULT
            B_OVERRIDES_A_AND_C
            B_OVERRIDES_C
            B_PATH_PREPENDS_A_AND_C
            C_DEFAULT
            D_DEFAULT
            D_OVERRIDES_A
            D_PATH_PREPENDS_A
          END_EXPECTED_OUTPUT

          expected.gsub!(/:/,File::PATH_SEPARATOR)

          out, err = fig(%w<--list-variables --list-all-configs>)
          out.should == expected
          err.should =~
            %r<No version in the package descriptor of "D" in an include statement in the \.fig file for "B/1\.2\.3:default" \(line>
        end
      end
    end

    describe 'with --list-tree' do
      describe 'no --list-all-configs' do
        before(:each) do
          clean_up_test_environment
          set_up_test_environment
        end

        it %q<lists no dependency variables when none should exist without a package.fig> do
          set_up_list_variables_packages

          out, err = fig(%w<--list-variables --list-tree E/1.2.3>)
          out.should == 'E/1.2.3'
          err.should == ''
        end

        it %q<lists no dependency variables when none should exist with a package.fig> do
          set_up_list_variables_packages
          create_package_dot_fig('E')

          expected = clean_expected(<<-END_EXPECTED_OUTPUT)
            <unpublished>
            '---E/1.2.3
          END_EXPECTED_OUTPUT

          out, err = fig(%w<--list-variables --list-tree>)
          out.should == expected
          err.should == ''
        end

        it %q<lists all dependency variables without a package.fig> do
          set_up_list_variables_packages

          expected = clean_expected(<<-END_EXPECTED_OUTPUT)
            A/1.2.3
            |   A_BOTH_CONFIGS                    = default
            |   A_DEFAULT                         = BAR
            |   D_OVERRIDES_A                     = A
            |   B_OVERRIDES_A_AND_C               = A
            |   A_PATH_DEFAULT                    = BAR:$A_PATH_DEFAULT
            |   D_PATH_PREPENDS_A                 = A:$D_PATH_PREPENDS_A
            |   B_PATH_PREPENDS_A_AND_C           = A:$B_PATH_PREPENDS_A_AND_C
            |   A_SET_GETS_PREPENDED_WITH_B_AND_C = A
            |   A_OVERRIDES_C_PREPENDING_B        = A
            |   A_OVERRIDES_B_AND_C               = A
            |   A_OVERRIDES_D                     = A
            |   A_PATH_PREPENDS_B_AND_C           = A:$A_PATH_PREPENDS_B_AND_C
            |   A_PATH_PREPENDS_D                 = A:$A_PATH_PREPENDS_D
            '---C/1.2.3
            |   |   C_DEFAULT                         = BAR
            |   |   B_OVERRIDES_C                     = C
            |   |   B_OVERRIDES_A_AND_C               = C
            |   |   A_OVERRIDES_B_AND_C               = C
            |   |   B_PATH_PREPENDS_A_AND_C           = C:$B_PATH_PREPENDS_A_AND_C
            |   |   A_PATH_PREPENDS_B_AND_C           = C:$A_PATH_PREPENDS_B_AND_C
            |   |   A_SET_GETS_PREPENDED_WITH_B_AND_C = C:$A_SET_GETS_PREPENDED_WITH_B_AND_C
            |   |   A_OVERRIDES_C_PREPENDING_B        = C:$A_OVERRIDES_C_PREPENDING_B
            |   '---D/1.2.3
            |       |   D_DEFAULT         = BAR
            |       |   A_OVERRIDES_D     = D
            |       |   D_OVERRIDES_A     = D
            |       |   D_PATH_PREPENDS_A = D:$D_PATH_PREPENDS_A
            |       |   A_PATH_PREPENDS_D = D:$A_PATH_PREPENDS_D
            |       '---D/1.2.3:addon_a
            |       |       ADDON_A = ding
            |       '---D/1.2.3:addon_b
            |       |   |   ADDON_B = dong
            |       |   '---E/1.2.3
            |       '---D/1.2.3:addon_c
            |               ADDON_C = dang
            '---B/1.2.3
                |   B_DEFAULT                         = BAR
                |   B_OVERRIDES_C                     = B
                |   B_OVERRIDES_A_AND_C               = B
                |   A_OVERRIDES_B_AND_C               = B
                |   B_PATH_PREPENDS_A_AND_C           = B:$B_PATH_PREPENDS_A_AND_C
                |   A_PATH_PREPENDS_B_AND_C           = B:$A_PATH_PREPENDS_B_AND_C
                |   A_SET_GETS_PREPENDED_WITH_B_AND_C = B:$A_SET_GETS_PREPENDED_WITH_B_AND_C
                |   A_OVERRIDES_C_PREPENDING_B        = B:$A_OVERRIDES_C_PREPENDING_B
                '---D/1.2.3
                    |   D_DEFAULT         = BAR
                    |   A_OVERRIDES_D     = D
                    |   D_OVERRIDES_A     = D
                    |   D_PATH_PREPENDS_A = D:$D_PATH_PREPENDS_A
                    |   A_PATH_PREPENDS_D = D:$A_PATH_PREPENDS_D
                    '---D/1.2.3:addon_a
                    |       ADDON_A = ding
                    '---D/1.2.3:addon_b
                    |   |   ADDON_B = dong
                    |   '---E/1.2.3
                    '---D/1.2.3:addon_c
                            ADDON_C = dang
          END_EXPECTED_OUTPUT

          out, err = fig(%w<--list-variables A/1.2.3 --list-tree>)
          out.should == expected
          err.should =~
            %r<No version in the package descriptor of "D" in an include statement in the \.fig file for "B/1\.2\.3:default" \(line>
        end

        it %q<lists all dependency variables with a package.fig> do
          set_up_list_variables_packages
          create_package_dot_fig('A')

          expected = clean_expected(<<-END_EXPECTED_OUTPUT)
            <unpublished>
            '---A/1.2.3
                |   A_BOTH_CONFIGS                    = default
                |   A_DEFAULT                         = BAR
                |   D_OVERRIDES_A                     = A
                |   B_OVERRIDES_A_AND_C               = A
                |   A_PATH_DEFAULT                    = BAR:$A_PATH_DEFAULT
                |   D_PATH_PREPENDS_A                 = A:$D_PATH_PREPENDS_A
                |   B_PATH_PREPENDS_A_AND_C           = A:$B_PATH_PREPENDS_A_AND_C
                |   A_SET_GETS_PREPENDED_WITH_B_AND_C = A
                |   A_OVERRIDES_C_PREPENDING_B        = A
                |   A_OVERRIDES_B_AND_C               = A
                |   A_OVERRIDES_D                     = A
                |   A_PATH_PREPENDS_B_AND_C           = A:$A_PATH_PREPENDS_B_AND_C
                |   A_PATH_PREPENDS_D                 = A:$A_PATH_PREPENDS_D
                '---C/1.2.3
                |   |   C_DEFAULT                         = BAR
                |   |   B_OVERRIDES_C                     = C
                |   |   B_OVERRIDES_A_AND_C               = C
                |   |   A_OVERRIDES_B_AND_C               = C
                |   |   B_PATH_PREPENDS_A_AND_C           = C:$B_PATH_PREPENDS_A_AND_C
                |   |   A_PATH_PREPENDS_B_AND_C           = C:$A_PATH_PREPENDS_B_AND_C
                |   |   A_SET_GETS_PREPENDED_WITH_B_AND_C = C:$A_SET_GETS_PREPENDED_WITH_B_AND_C
                |   |   A_OVERRIDES_C_PREPENDING_B        = C:$A_OVERRIDES_C_PREPENDING_B
                |   '---D/1.2.3
                |       |   D_DEFAULT         = BAR
                |       |   A_OVERRIDES_D     = D
                |       |   D_OVERRIDES_A     = D
                |       |   D_PATH_PREPENDS_A = D:$D_PATH_PREPENDS_A
                |       |   A_PATH_PREPENDS_D = D:$A_PATH_PREPENDS_D
                |       '---D/1.2.3:addon_a
                |       |       ADDON_A = ding
                |       '---D/1.2.3:addon_b
                |       |   |   ADDON_B = dong
                |       |   '---E/1.2.3
                |       '---D/1.2.3:addon_c
                |               ADDON_C = dang
                '---B/1.2.3
                    |   B_DEFAULT                         = BAR
                    |   B_OVERRIDES_C                     = B
                    |   B_OVERRIDES_A_AND_C               = B
                    |   A_OVERRIDES_B_AND_C               = B
                    |   B_PATH_PREPENDS_A_AND_C           = B:$B_PATH_PREPENDS_A_AND_C
                    |   A_PATH_PREPENDS_B_AND_C           = B:$A_PATH_PREPENDS_B_AND_C
                    |   A_SET_GETS_PREPENDED_WITH_B_AND_C = B:$A_SET_GETS_PREPENDED_WITH_B_AND_C
                    |   A_OVERRIDES_C_PREPENDING_B        = B:$A_OVERRIDES_C_PREPENDING_B
                    '---D/1.2.3
                        |   D_DEFAULT         = BAR
                        |   A_OVERRIDES_D     = D
                        |   D_OVERRIDES_A     = D
                        |   D_PATH_PREPENDS_A = D:$D_PATH_PREPENDS_A
                        |   A_PATH_PREPENDS_D = D:$A_PATH_PREPENDS_D
                        '---D/1.2.3:addon_a
                        |       ADDON_A = ding
                        '---D/1.2.3:addon_b
                        |   |   ADDON_B = dong
                        |   '---E/1.2.3
                        '---D/1.2.3:addon_c
                                ADDON_C = dang
          END_EXPECTED_OUTPUT

          out, err = fig(%w<--list-variables --list-tree>)

          out.should == expected
          err.should =~
            %r<No version in the package descriptor of "D" in an include statement in the \.fig file for "B/1\.2\.3:default" \(line>
        end
      end

      describe 'with --list-all-configs' do
        before(:each) do
          clean_up_test_environment
          set_up_test_environment
        end

        it %q<lists no dependency variables when none should exist without a package.fig> do
          set_up_list_variables_packages

          out, err =
            fig(%w<--list-variables --list-all-configs --list-tree E/1.2.3>)
          out.should == 'E/1.2.3'
          err.should == ''
        end

        it %q<lists no dependency variables when none should exist with a package.fig> do
          set_up_list_variables_packages
          create_package_dot_fig('E')

          expected = clean_expected(<<-END_EXPECTED_OUTPUT)
            <unpublished>
            '---E/1.2.3
          END_EXPECTED_OUTPUT

          out, err = fig(%w<--list-variables --list-all-configs --list-tree>)
          out.should == expected
          err.should == ''
        end

        it %q<lists all dependency variables without a package.fig> do
          set_up_list_variables_packages

          expected = clean_expected(<<-END_EXPECTED_OUTPUT)
            A/1.2.3
            |   A_BOTH_CONFIGS                    = default
            |   A_DEFAULT                         = BAR
            |   D_OVERRIDES_A                     = A
            |   B_OVERRIDES_A_AND_C               = A
            |   A_PATH_DEFAULT                    = BAR:$A_PATH_DEFAULT
            |   D_PATH_PREPENDS_A                 = A:$D_PATH_PREPENDS_A
            |   B_PATH_PREPENDS_A_AND_C           = A:$B_PATH_PREPENDS_A_AND_C
            |   A_SET_GETS_PREPENDED_WITH_B_AND_C = A
            |   A_OVERRIDES_C_PREPENDING_B        = A
            |   A_OVERRIDES_B_AND_C               = A
            |   A_OVERRIDES_D                     = A
            |   A_PATH_PREPENDS_B_AND_C           = A:$A_PATH_PREPENDS_B_AND_C
            |   A_PATH_PREPENDS_D                 = A:$A_PATH_PREPENDS_D
            '---C/1.2.3
            |   |   C_DEFAULT                         = BAR
            |   |   B_OVERRIDES_C                     = C
            |   |   B_OVERRIDES_A_AND_C               = C
            |   |   A_OVERRIDES_B_AND_C               = C
            |   |   B_PATH_PREPENDS_A_AND_C           = C:$B_PATH_PREPENDS_A_AND_C
            |   |   A_PATH_PREPENDS_B_AND_C           = C:$A_PATH_PREPENDS_B_AND_C
            |   |   A_SET_GETS_PREPENDED_WITH_B_AND_C = C:$A_SET_GETS_PREPENDED_WITH_B_AND_C
            |   |   A_OVERRIDES_C_PREPENDING_B        = C:$A_OVERRIDES_C_PREPENDING_B
            |   '---D/1.2.3
            |       |   D_DEFAULT         = BAR
            |       |   A_OVERRIDES_D     = D
            |       |   D_OVERRIDES_A     = D
            |       |   D_PATH_PREPENDS_A = D:$D_PATH_PREPENDS_A
            |       |   A_PATH_PREPENDS_D = D:$A_PATH_PREPENDS_D
            |       '---D/1.2.3:addon_a
            |       |       ADDON_A = ding
            |       '---D/1.2.3:addon_b
            |       |   |   ADDON_B = dong
            |       |   '---E/1.2.3
            |       '---D/1.2.3:addon_c
            |               ADDON_C = dang
            '---B/1.2.3
                |   B_DEFAULT                         = BAR
                |   B_OVERRIDES_C                     = B
                |   B_OVERRIDES_A_AND_C               = B
                |   A_OVERRIDES_B_AND_C               = B
                |   B_PATH_PREPENDS_A_AND_C           = B:$B_PATH_PREPENDS_A_AND_C
                |   A_PATH_PREPENDS_B_AND_C           = B:$A_PATH_PREPENDS_B_AND_C
                |   A_SET_GETS_PREPENDED_WITH_B_AND_C = B:$A_SET_GETS_PREPENDED_WITH_B_AND_C
                |   A_OVERRIDES_C_PREPENDING_B        = B:$A_OVERRIDES_C_PREPENDING_B
                '---D/1.2.3
                    |   D_DEFAULT         = BAR
                    |   A_OVERRIDES_D     = D
                    |   D_OVERRIDES_A     = D
                    |   D_PATH_PREPENDS_A = D:$D_PATH_PREPENDS_A
                    |   A_PATH_PREPENDS_D = D:$A_PATH_PREPENDS_D
                    '---D/1.2.3:addon_a
                    |       ADDON_A = ding
                    '---D/1.2.3:addon_b
                    |   |   ADDON_B = dong
                    |   '---E/1.2.3
                    '---D/1.2.3:addon_c
                            ADDON_C = dang
            A/1.2.3:nondefault
            |   A_BOTH_CONFIGS = nondefault
            |   A_NONDEFAULT   = BAZ
            '---C/4.5.6:nondefault
                    C_ONLY_IN_C456 = C
          END_EXPECTED_OUTPUT

          out, err =
            fig(%w<--list-variables --list-all-configs --list-tree A/1.2.3>)
          out.should == expected
          err.should =~
            %r<No version in the package descriptor of "D" in an include statement in the \.fig file for "B/1\.2\.3:default" \(line>
        end

        it %q<lists all dependency variables with a package.fig> do
          set_up_list_variables_packages
          create_package_dot_fig('A')

          expected = clean_expected(<<-'END_EXPECTED_OUTPUT')
            <unpublished>
            '---A/1.2.3
                |   A_BOTH_CONFIGS                    = default
                |   A_DEFAULT                         = BAR
                |   D_OVERRIDES_A                     = A
                |   B_OVERRIDES_A_AND_C               = A
                |   A_PATH_DEFAULT                    = BAR:$A_PATH_DEFAULT
                |   D_PATH_PREPENDS_A                 = A:$D_PATH_PREPENDS_A
                |   B_PATH_PREPENDS_A_AND_C           = A:$B_PATH_PREPENDS_A_AND_C
                |   A_SET_GETS_PREPENDED_WITH_B_AND_C = A
                |   A_OVERRIDES_C_PREPENDING_B        = A
                |   A_OVERRIDES_B_AND_C               = A
                |   A_OVERRIDES_D                     = A
                |   A_PATH_PREPENDS_B_AND_C           = A:$A_PATH_PREPENDS_B_AND_C
                |   A_PATH_PREPENDS_D                 = A:$A_PATH_PREPENDS_D
                '---C/1.2.3
                |   |   C_DEFAULT                         = BAR
                |   |   B_OVERRIDES_C                     = C
                |   |   B_OVERRIDES_A_AND_C               = C
                |   |   A_OVERRIDES_B_AND_C               = C
                |   |   B_PATH_PREPENDS_A_AND_C           = C:$B_PATH_PREPENDS_A_AND_C
                |   |   A_PATH_PREPENDS_B_AND_C           = C:$A_PATH_PREPENDS_B_AND_C
                |   |   A_SET_GETS_PREPENDED_WITH_B_AND_C = C:$A_SET_GETS_PREPENDED_WITH_B_AND_C
                |   |   A_OVERRIDES_C_PREPENDING_B        = C:$A_OVERRIDES_C_PREPENDING_B
                |   '---D/1.2.3
                |       |   D_DEFAULT         = BAR
                |       |   A_OVERRIDES_D     = D
                |       |   D_OVERRIDES_A     = D
                |       |   D_PATH_PREPENDS_A = D:$D_PATH_PREPENDS_A
                |       |   A_PATH_PREPENDS_D = D:$A_PATH_PREPENDS_D
                |       '---D/1.2.3:addon_a
                |       |       ADDON_A = ding
                |       '---D/1.2.3:addon_b
                |       |   |   ADDON_B = dong
                |       |   '---E/1.2.3
                |       '---D/1.2.3:addon_c
                |               ADDON_C = dang
                '---B/1.2.3
                    |   B_DEFAULT                         = BAR
                    |   B_OVERRIDES_C                     = B
                    |   B_OVERRIDES_A_AND_C               = B
                    |   A_OVERRIDES_B_AND_C               = B
                    |   B_PATH_PREPENDS_A_AND_C           = B:$B_PATH_PREPENDS_A_AND_C
                    |   A_PATH_PREPENDS_B_AND_C           = B:$A_PATH_PREPENDS_B_AND_C
                    |   A_SET_GETS_PREPENDED_WITH_B_AND_C = B:$A_SET_GETS_PREPENDED_WITH_B_AND_C
                    |   A_OVERRIDES_C_PREPENDING_B        = B:$A_OVERRIDES_C_PREPENDING_B
                    '---D/1.2.3
                        |   D_DEFAULT         = BAR
                        |   A_OVERRIDES_D     = D
                        |   D_OVERRIDES_A     = D
                        |   D_PATH_PREPENDS_A = D:$D_PATH_PREPENDS_A
                        |   A_PATH_PREPENDS_D = D:$A_PATH_PREPENDS_D
                        '---D/1.2.3:addon_a
                        |       ADDON_A = ding
                        '---D/1.2.3:addon_b
                        |   |   ADDON_B = dong
                        |   '---E/1.2.3
                        '---D/1.2.3:addon_c
                                ADDON_C = dang
          END_EXPECTED_OUTPUT

          out, err = fig(%w<--list-variables --list-all-configs --list-tree>)

          out.should == expected
          err.should =~
            %r<No version in the package descriptor of "D" in an include statement in the \.fig file for "B/1\.2\.3:default" \(line>
        end
      end
    end

    describe %q<handles "include ... override ...> do
      before(:each) do
        clean_up_test_environment
        set_up_test_environment
        set_up_packages_with_overrides
        remove_any_package_dot_fig
      end

      it %<plain (goes through RuntimeEnvironment object)> do
        expected = clean_expected(<<-END_EXPECTED_OUTPUT)
          C=4.5.6
        END_EXPECTED_OUTPUT

        out, err = fig(%w<--list-variables A/1.2.3>)
        out.should == expected
        err.should == ''
      end

      it %<with --list-tree (goes through PackageCache object)> do
        expected = clean_expected(<<-END_EXPECTED_OUTPUT)
          A/1.2.3
          '---B/1.2.3
              '---C/4.5.6
              |   |   C = 4.5.6
              |   '---D/4.5.6
              '---D/4.5.6
        END_EXPECTED_OUTPUT

        out, err = fig(%w<--list-variables --list-tree A/1.2.3>)
        out.should == expected
        err.should == ''
      end
    end

    it %q<should complain if local repository isn't in the expected format version> do
      clean_up_test_environment
      set_up_test_environment
      set_up_packages_with_overrides
      remove_any_package_dot_fig
      set_local_repository_format_to_future_version

      out, err, exit_code =
        fig(%w<--list-variables A/1.2.3>, :no_raise_on_error => true)
      exit_code.should_not == 0
      err.should =~
        /Local repository is in version \d+ format. This version of fig can only deal with repositories in version \d+ format\./
    end
  end
end
