SparkleFormation.new(:lint_invalid) do
  dynamic!(:s3_bucket, :test)
  resources.bad_resource.type 'Invalid::Resource'
end
