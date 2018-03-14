require 'atmos'
require 'clamp'

module Atmos::Commands

  class Bootstrap < Clamp::Command
    include GemLogger::LoggerSupport

    def self.description
      "Sets up the initial aws account for use by atmos"
    end

    option ["-f", "--force"],
           :flag, "forces bootstrap\n"

    def execute

      tf_init_dir = File.join(Atmos.config.tf_working_dir, '.terraform')
      tf_initialized = File.exist?(tf_init_dir)
      backend_initialized = File.exist?(File.join(tf_init_dir, 'terraform.tfstate'))

      rebootstrap_msg = <<~EOF
        Bootstrap should only be performed when provisioning an account for the first
        time.  Try 'atmos terraform init'
      EOF

      if !force? && tf_initialized
        signal_usage_error(rebootstrap_msg)
      end

      Atmos.config.provider.auth_manager.authenticate(ENV) do |auth_env|
        begin
          exe = Atmos::TerraformExecutor.new(process_env: auth_env)

          skip_backend = true
          skip_secrets = true
          if backend_initialized
            skip_backend = false
            skip_secrets = false
          end

          # Cases
          # 1) bootstrap of new account - success
          # 2) repeating bootstrap of new account due to failure partway - success
          # 3) try to rebootstrap existing account on fresh checkout - should fail trying to create resources of same name, check output for this?
          # 4) bootstrap new account with no-default secrets

          # Need to init before we can create the resources to store state in bootstrap
          exe.run("init", "-input=false", "-lock=false",
                  skip_backend: true, skip_secrets: true)

          # Bootstrap to create the resources needed to store state and basic user
          bootstrap_target = "null_resource.bootstrap-#{Atmos.config.atmos_env == 'ops' ? 'ops' : 'env'}"
          exe.run("apply", "-input=false", "-target", bootstrap_target,
                  skip_backend: true, skip_secrets: true)

          # Need to init to setup the backend state after we create the resources
          # to store state in bootstrap
          exe.run("init", "-input=false", "-force-copy")

        rescue Atmos::TerraformExecutor::ProcessFailed => e
          logger.error(e.message)
          logger.error(rebootstrap_msg)
        end
      end
    end

  end

end