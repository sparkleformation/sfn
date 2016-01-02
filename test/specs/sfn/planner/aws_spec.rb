require_relative '../../../helper'
require 'sfn/planner/aws'

describe Sfn::Planner::Aws do
  it "does not blow up on Outputs keys" do
    results = {:outputs => {}}
    planner = Sfn::Planner::Aws.new(nil, nil, nil, nil)
    planner.send(:register_diff, results, 'Outputs', {}, nil, {})
    results.must_equal :outputs => {"Outputs" => {:properties => []}}
  end
end
