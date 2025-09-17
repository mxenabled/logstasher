require "spec_helper"
require "dry-validation"

describe ::LogStasher do
  before(:each) do
    # Reset state before each test
    ::LogStasher.metadata = {}
    ::LogStasher.dry_validation_contract = nil
  end
  describe "#log_as_json" do
    it "calls the logger with the payload" do
      expect(::LogStasher.logger).to receive(:<<) do |json|
        expect(::JSON.parse(json)).to eq("yolo" => "brolo")
      end

      ::LogStasher.log_as_json({"yolo" => "brolo"})
    end

    context "with event" do
      it "calls logger with a logstash event" do
        expect(::LogStasher.logger).to receive(:<<) do |json|
          payload = ::JSON.parse(json)

          expect(payload["@timestamp"]).to_not be_nil
          expect(payload["@version"]).to eq("1")
          expect(payload["yolo"]).to eq("brolo")
        end

        ::LogStasher.log_as_json({"yolo" => "brolo"}, :as_logstash_event => true)
      end
    end

    context "with metadata" do
      before { ::LogStasher.metadata = { :namespace => :cooldude } }
      after { ::LogStasher.metadata = {} }

      it "calls logger with the metadata" do
        expect(::LogStasher.logger).to receive(:<<) do |json|
          expect(::JSON.parse(json)).to eq("yolo" => "brolo", "metadata" => { "namespace" => "cooldude" })
        end

        ::LogStasher.log_as_json({"yolo" => "brolo"})
      end

      it "merges metadata for LogStash::Event types" do
        expect(::LogStasher.logger).to receive(:<<) do |json|
          expect(::JSON.parse(json)).to match(a_hash_including("yolo" => "brolo", "metadata" => { "namespace" => "cooldude" }))
        end

        ::LogStasher.log_as_json(::LogStash::Event.new("yolo" => "brolo"))
      end

      it "does not merge metadata on an array" do
        expect(::LogStasher.logger).to receive(:<<) do |json|
          expect(::JSON.parse(json)).to eq([{ "yolo" => "brolo" }])
        end

        ::LogStasher.log_as_json([{"yolo" => "brolo"}])
      end
    end

    context "with dry validation contract" do
      let(:validation_contract) do
        Class.new(Dry::Validation::Contract) do
          params do
            required(:yolo).filled(:string)
          end
        end.new
      end

      before do
        ::LogStasher.metadata = { :namespace => :cooldude }
        ::LogStasher.dry_validation_contract = validation_contract
      end

      after do
        ::LogStasher.metadata = {}
        ::LogStasher.dry_validation_contract = nil
      end

      it "validates LogStash::Event payload and appends validation metadata on success" do
        expect(::LogStasher.logger).to receive(:<<) do |json|
          payload = ::JSON.parse(json)
          expect(payload["dry_validation_errors"]).to eq("{}")
          expect(payload["dry_validation_success"]).to be true
          expect(payload["yolo"]).to eq("brolo")
          expect(payload["metadata"]["namespace"]).to eq("cooldude")
        end

        ::LogStasher.log_as_json(::LogStash::Event.new("yolo" => "brolo"))
      end

      it "validates LogStash::Event payload and appends validation metadata on failure" do
        expect(::LogStasher.logger).to receive(:<<) do |json|
          payload = ::JSON.parse(json)
          expect(payload["dry_validation_errors"]).to eq("{\"yolo\":[\"must be a string\"]}")
          expect(payload["dry_validation_success"]).to be false
          expect(payload["yolo"]).to eq(123)
          expect(payload["metadata"]["namespace"]).to eq("cooldude")
        end

        ::LogStasher.log_as_json(::LogStash::Event.new("yolo" => 123))
      end

      it "validates hash payload and merges validation metadata on success" do
        expect(::LogStasher.logger).to receive(:<<) do |json|
          payload = ::JSON.parse(json)
          expect(payload["dry_validation_errors"]).to eq("{}")
          expect(payload["dry_validation_success"]).to be true
          expect(payload["yolo"]).to eq("brolo")
          expect(payload["metadata"]["namespace"]).to eq("cooldude")
        end

        ::LogStasher.log_as_json({"yolo" => "brolo"})
      end

      it "validates hash payload and merges validation metadata on failure" do
        expect(::LogStasher.logger).to receive(:<<) do |json|
          payload = ::JSON.parse(json)
          expect(payload["dry_validation_errors"]).to eq("{\"yolo\":[\"must be a string\"]}")
          expect(payload["dry_validation_success"]).to be false
          expect(payload["yolo"]).to eq(123)
          expect(payload["metadata"]["namespace"]).to eq("cooldude")
        end

        ::LogStasher.log_as_json({"yolo" => 123})
      end

      it "does not validate array payloads" do
        expect(::LogStasher.logger).to receive(:<<) do |json|
          payload = ::JSON.parse(json)
          expect(payload).to eq([{ "yolo" => "brolo" }])
        end

        ::LogStasher.log_as_json([{"yolo" => "brolo"}])
      end

      it "formats the payload correctly for the contract call" do
        expect(::LogStasher.logger).to receive(:<<) do |json|
          payload = ::JSON.parse(json)
          expect(payload["dry_validation_errors"]).to eq("{}")
          expect(payload["dry_validation_success"]).to be true
          expect(payload["yolo"]).to eq("brolo")
          expect(payload["metadata"]["namespace"]).to eq("cooldude")
        end

        ::LogStasher.log_as_json(::LogStash::Event.new("yolo" => :brolo))
      end
    end
  end

  describe "#dry_validation_contract=" do
    it "accepts a valid Dry::Validation::Contract" do
      contract = Class.new(Dry::Validation::Contract) do
        params do
          required(:test).filled(:string)
        end
      end.new

      expect { ::LogStasher.dry_validation_contract = contract }.not_to raise_error
      expect(::LogStasher.dry_validation_contract).to eq(contract)
    end

    it "accepts nil" do
      expect { ::LogStasher.dry_validation_contract = nil }.not_to raise_error
      expect(::LogStasher.dry_validation_contract).to be_nil
    end

    it "raises ArgumentError for non-Contract objects" do
      expect { ::LogStasher.dry_validation_contract = "not a contract" }.to raise_error(
        ArgumentError, "Expected a Dry::Validation::Contract, got String"
      )
    end
  end

  describe "#dry_validation_contract" do
    it "returns the stored contract" do
      contract = double("contract")
      ::LogStasher.instance_variable_set(:@dry_validation_contract, contract)
      expect(::LogStasher.dry_validation_contract).to eq(contract)
    end

    it "returns nil when no contract is set" do
      ::LogStasher.instance_variable_set(:@dry_validation_contract, nil)
      expect(::LogStasher.dry_validation_contract).to be_nil
    end
  end

  describe "#load_from_config" do
    before(:each) do
      ::LogStasher.metadata = {}
      ::LogStasher.serialize_parameters = true
      ::LogStasher.silence_standard_logging = false
    end

    it "loads with multiple config keys" do
      config = {
        metadata: {
          namespace: 'kirby',
          logged_via: 'logstasher',
        },
        device: {
          type: 'stdout'
        }
      }

      ::LogStasher.load_from_config(config)
      expect(::LogStasher.metadata).to eq({:namespace => 'kirby', :logged_via => 'logstasher'})
      expect(::LogStasher.default_device).to eq(STDOUT)
    end

    it "loads metadata" do
      config = {
        metadata: {
          namespace: 'kirby',
          logged_via: 'logstasher',
        }
      }

      ::LogStasher.load_from_config(config)
      expect(::LogStasher.metadata).to eq({:namespace => 'kirby', :logged_via => 'logstasher'})
    end

    it "loads parameters" do
      config = {
        include_parameters: false,
        serialize_parameters: false,
        silence_standard_logging: true,
        silence_creation_message: false
      }

      ::LogStasher.load_from_config(config)
      expect(::LogStasher.instance_variable_get(:@include_parameters)).to be false
      expect(::LogStasher.instance_variable_get(:@serialize_parameters)).to be false
      expect(::LogStasher.instance_variable_get(:@silence_standard_logging)).to be true
    end

    it "loads with a stdout device" do
      config = {
        metadata: {
          namespace: 'kirby',
          logged_via: 'logstasher',
        }
      }

      ::LogStasher.load_from_config(config)
      expect(::LogStasher.metadata).to eq({:namespace => 'kirby', :logged_via => 'logstasher'})
    end

    it "loads with a syslog device" do
      config = {
        device:
          {
            type: 'syslog',
            identity: 'logstasher',
            facility: 'LOG_LOCAL1',
            priority: 'LOG_INFO',
            flags: ['LOG_PID', 'LOG_CONS']
          }
      }
      ::LogStasher.load_from_config(config)
      expect(::LogStasher.metadata).to eq({})
      expect(::LogStasher.default_device).to be_a ::LogStasher::Device::Syslog
    end
  end

end
