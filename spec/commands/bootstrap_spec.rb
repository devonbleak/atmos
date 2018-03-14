require "atmos/commands/bootstrap"
require "atmos/terraform_executor"

describe Atmos::Commands::Bootstrap do

  let(:cli) { described_class.new("") }

  around(:each) do |ex|
    within_construct do |c|
      @c = c
      c.file('config/atmos.yml')
      Atmos.config = Atmos::Config.new("ops")
      ex.run
      Atmos.config = nil
    end
  end


  describe "--help" do

    it "produces help text under standard width" do
      expect(cli.help).to be_line_width_for_cli
    end

  end

  describe "execute" do

    it "runs against a fresh repo" do
      env = Hash.new
      te = double(Atmos::TerraformExecutor)
      expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
      expect(Atmos::TerraformExecutor).to receive(:new).and_return(te)
      expect(te).to receive(:run).with("init", "-input=false", "-lock=false",
                        skip_backend: true, skip_secrets: true)
      expect(te).to receive(:run).with("apply", "-input=false", "-target", "null_resource.bootstrap-ops",
                        skip_backend: true, skip_secrets: true)
      expect(te).to receive(:run).with("init", "-input=false", "-force-copy")
      cli.run([])
    end

    it "uses env bootstrap target" do
      Atmos.config = Atmos::Config.new("dev")
      env = Hash.new
      te = double(Atmos::TerraformExecutor)
      expect(Atmos.config.provider.auth_manager).to receive(:authenticate).and_yield(env)
      expect(Atmos::TerraformExecutor).to receive(:new).and_return(te)
      expect(te).to receive(:run).with("init", "-input=false", "-lock=false",
                        skip_backend: true, skip_secrets: true)
      expect(te).to receive(:run).with("apply", "-input=false", "-target", "null_resource.bootstrap-env",
                        skip_backend: true, skip_secrets: true)
      expect(te).to receive(:run).with("init", "-input=false", "-force-copy")
      cli.run([])
    end

    it "aborts if already initialized" do
      @c.directory(File.join(Atmos.config.tf_working_dir, '.terraform'))
      expect { cli.run([]) }.to raise_error(Clamp::UsageError, /first/)
    end

    # TODO: full terraform integration test
  end

end