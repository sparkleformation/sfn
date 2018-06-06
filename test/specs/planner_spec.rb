require_relative "../helper"

describe Sfn::Planner do
  let(:api) do
    unless @api
      @api = mock
    end
    @api
  end
  let(:default_stack_data) do
    Smash.new(
      :id => "_TEST_ID_",
      :name => "_TEST_NAME_",
    )
  end
  let(:stack_data) { Smash.new }
  let(:stack) do
    unless @stack
      @stack = Miasma::Models::Orchestration::Stack.new(
        api, default_stack_data.merge(stack_data)
      ).valid_state
      @stack.parameters = stack_parameters
    end
    @stack
  end
  let(:stack_parameters) { Smash.new }
  let(:config) { Smash.new }
  let(:arguments) { [] }
  let(:options) { Smash.new }
  let(:planner_type) { Sfn::Planner }
  let(:planner) do
    planner_type.new(ui, config, arguments, stack, options)
  end

  it "should raise error on plan generation" do
    -> { planner.generate_plan({}, {}) }.must_raise NotImplementedError
  end

  describe Sfn::Planner::Aws do
    let(:stack_data) do
      Smash.new(
        :parameters => {},
        :template => {},
      )
    end
    let(:planner_type) { Sfn::Planner::Aws }

    before do
      api.expects(:aws_region).returns("us-west-2").at_least_once
      api.expects(:stack_reload).at_least_once
    end

    it "should return empty plan when templates are empty" do
      api.expects(:stack_template_load).returns({}).at_least_once
      result = planner.generate_plan({}, {})
      result.must_be :empty?
    end

    describe "Resource modification" do
      before do
        api.expects(:data).returns({}).at_least_once
      end

      let(:template) do
        Smash.new(
          "Resources" => {
            "Ec2Instance" => {
              "Type" => "AWS::EC2::Instance",
              "Properties" => {
                "AvailabilityZone" => "there",
                "ImageId" => "ack",
              },
            },
          },
        )
      end

      it "should flag Ec2Instance for replacement on image id" do
        api.expects(:stack_template_load).returns(
          {
            "Resources" => {
              "Ec2Instance" => {
                "Type" => "AWS::EC2::Instance",
                "Properties" => {
                  "AvailabilityZone" => "there",
                  "ImageId" => "quack",
                },
              },
            },
          }
        ).at_least_once
        result = planner.generate_plan(template, {}).stacks[stack.name]
        item = result.replace.first
        item.name.must_equal "Ec2Instance"
        item.type.must_equal "AWS::EC2::Instance"
        item.diffs.map(&:name).must_include "ImageId"
      end

      it "should flag Ec2Instance for replacement" do
        api.expects(:stack_template_load).returns(
          {
            "Resources" => {
              "Ec2Instance" => {
                "Type" => "AWS::EC2::Instance",
                "Properties" => {
                  "AvailabilityZone" => "here",
                  "ImageId" => "ack",
                },
              },
            },
          }
        ).at_least_once
        result = planner.generate_plan(template, {}).stacks[stack.name]
        item = result.replace.first
        item.name.must_equal "Ec2Instance"
        item.type.must_equal "AWS::EC2::Instance"
        item.diffs.map(&:name).must_include "AvailabilityZone"
      end
    end

    describe "Resource removal" do
      before do
        api.expects(:data).returns({}).at_least_once
      end

      let(:template) do
        Smash.new(
          "Resources" => {},
        )
      end

      it "should return Ec2Instance removal" do
        api.expects(:stack_template_load).returns(
          {
            "Resources" => {
              "Ec2Instance" => {
                "Type" => "AWS::EC2::Instance",
                "Properties" => {
                  "ImageId" => "quack",
                },
              },
            },
          }
        ).at_least_once
        result = planner.generate_plan(template, {}).stacks[stack.name]
        item = result.remove.first
        item.name.must_equal "Ec2Instance"
        item.type.must_equal "AWS::EC2::Instance"
      end
    end

    describe "Resource addition" do
      before do
        api.expects(:data).returns({}).at_least_once
      end

      let(:template) do
        Smash.new(
          "Resources" => {
            "Ec2Instance" => {
              "Type" => "AWS::EC2::Instance",
              "Properties" => {
                "ImageId" => "ack",
              },
            },
          },
        )
      end

      it "should return empty plan when templates are empty" do
        api.expects(:stack_template_load).returns(
          {
            "Resources" => {},
          }
        ).at_least_once
        result = planner.generate_plan(template, {}).stacks[stack.name]
        item = result.add.first
        item.name.must_equal "Ec2Instance"
        item.type.must_equal "AWS::EC2::Instance"
      end
    end

    describe "Parameter types on update" do
      before do
        api.expects(:data).returns({}).at_least_once
      end

      let(:template) do
        Smash.new(
          "Parameters" => {
            "TestParam" => {
              "Type" => "Number",
            },
          },
          "Resources" => {
            "Ec2Instance" => {
              "Type" => "AWS::EC2::Instance",
              "Properties" => {
                "ImageId" => {
                  "Ref" => "TestParam",
                },
              },
            },
          },
        )
      end

      let(:stack_parameters) do
        {"TestParam" => 1}.to_smash
      end

      it "should return empty plan when parameters are different types but equivalent" do
        api.expects(:stack_template_load).returns(
          {
            "Parameters" => {
              "TestParam" => {
                "Type" => "Number",
              },
            },
            "Resources" => {
              "Ec2Instance" => {
                "Type" => "AWS::EC2::Instance",
                "Properties" => {
                  "ImageId" => {
                    "Ref" => "TestParam",
                  },
                },
              },
            },
          }
        ).at_least_once
        result = planner.generate_plan(template, {"TestParam" => "1"}).stacks[stack.name]
        result.replace.must_be :empty?
      end
    end

    describe "Template data types within planner" do
      before do
        api.expects(:data).returns({}).at_least_once
      end

      let(:template) do
        Smash.new(
          "Resources" => {
            "Ec2Instance" => {
              "Type" => "AWS::EC2::Instance",
              "Properties" => {
                "ImageId" => 100,
              },
            },
          },
        )
      end

      it "should not flag removal due to type difference" do
        api.expects(:stack_template_load).returns(
          {
            "Resources" => {
              "Ec2Instance" => {
                "Type" => "AWS::EC2::Instance",
                "Properties" => {
                  "ImageId" => "100",
                },
              },
            },
          }
        ).at_least_once
        result = planner.generate_plan(template, {}).stacks[stack.name]
        result.remove.must_be :empty?
      end
    end

    describe "Template conditionals" do
      before do
        api.expects(:data).returns({}).at_least_once
      end

      let(:template) do
        Smash.new(
          "Parameters" => {
            "Enabled" => {
              "Type" => "String",
            },
          },
          "Conditions" => {
            "IsEnabled" => {
              "Fn::Equals" => [
                {"Ref" => "Enabled"}, "yes",
              ],
            },
          },
          "Resources" => {
            "Ec2Instance" => {
              "Type" => "AWS::EC2::Instance",
              "Properties" => {
                "ImageId" => {
                  "Fn::If" => ["IsEnabled", 100, 200],
                },
              },
            },
          },
        )
      end

      describe "parameter does not change condition" do
        let(:stack_parameters) do
          Smash.new("Enabled" => "yes")
        end

        it "should not flag removal" do
          api.expects(:stack_template_load).returns(template).at_least_once
          result = planner.generate_plan(template, stack_parameters).stacks[stack.name]
          result.remove.must_be :empty?
        end
      end

      describe "parameter changes condition" do
        let(:stack_parameters) do
          Smash.new("Enabled" => "yes")
        end

        it "should flag removal" do
          api.expects(:stack_template_load).returns(template).at_least_once
          result = planner.generate_plan(template, Smash.new("Enabled" => "no")).stacks[stack.name]
          result.replace.map(&:name).must_include "Ec2Instance"
        end
      end

      describe "resource specific conditions" do
        let(:template) do
          Smash.new(
            "Parameters" => {
              "Enabled" => {
                "Type" => "String",
              },
            },
            "Conditions" => {
              "IsEnabled" => {
                "Fn::Equals" => [
                  {"Ref" => "Enabled"}, "yes",
                ],
              },
            },
            "Resources" => {
              "Ec2Instance" => {
                "OnCondition" => "IsEnabled",
                "Type" => "AWS::EC2::Instance",
                "Properties" => {
                  "ImageId" => 9,
                },
              },
            },
          )
        end

        describe "parameter does not change condition" do
          let(:stack_parameters) do
            Smash.new("Enabled" => "yes")
          end

          it "should not flag removal" do
            api.expects(:stack_template_load).returns(template).at_least_once
            result = planner.generate_plan(template, stack_parameters).stacks[stack.name]
            result.remove.must_be :empty?
          end
        end

        describe "parameter changes condition" do
          let(:stack_parameters) do
            Smash.new("Enabled" => "yes")
          end

          it "should flag removal" do
            api.expects(:stack_template_load).returns(template).at_least_once
            result = planner.generate_plan(template, Smash.new("Enabled" => "no")).stacks[stack.name]
            result.remove.map(&:name).must_include "Ec2Instance"
          end
        end
      end

      describe "resource modification ref conditionals" do
        let(:template) do
          Smash.new(
            "Parameters" => {
              "NodeImageId" => {
                "Type" => "String",
              },
            },
            "Conditions" => {
              "InSpecificAz" => {
                "Fn::Equals" => [
                  {
                    "Fn::GetAtt" => [
                      {"Ref" => "Ec2Instance"},
                      "AvailabilityZone",
                    ],
                  },
                  "us-west-1",
                ],
              },
            },
            "Resources" => {
              "Ec2Instance" => {
                "Type" => "AWS::EC2::Instance",
                "Properties" => {
                  "ImageId" => {
                    "Ref" => "NodeImageId",
                  },
                },
              },
              "OtherEc2Instance" => {
                "Type" => "AWS::EC2::Instance",
                "Properties" => {
                  "ImageId" => {
                    "Fn::If" => [
                      "InSpecificAz",
                      {"Ref" => "NodeImageId"},
                      "12",
                    ],
                  },
                },
              },
            },
          )
        end

        describe "when resource is not modified" do
          let(:stack_parameters) do
            Smash.new("NodeImageId" => "11")
          end

          it "should not flag removal" do
            api.expects(:stack_template_load).returns(template).at_least_once
            result = planner.generate_plan(template, stack_parameters).stacks[stack.name]
            result.remove.must_be :empty?
          end
        end

        describe "when resource is modified" do
          let(:stack_parameters) do
            Smash.new("NodeImageId" => "11")
          end

          it "should flag unknown" do
            api.expects(:stack_template_load).returns(template).at_least_once
            result = planner.generate_plan(template, Smash.new("NodeImageId" => "22")).stacks[stack.name]
            result.unknown.map(&:name).must_include "OtherEc2Instance"
          end
        end
      end
    end
  end
end
