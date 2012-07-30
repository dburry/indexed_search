
# for each test in the current context, set a global class variable and then restore it to previous value
def set_nested_global(klass, variable, value)
  before(:all) do
    @nested_global_defaults ||= Hash.new { |h,k| h[k] = Hash.new { |h,k| h[k] = [] } }
  end
  before(:each) do
    @nested_global_defaults[klass][variable] << klass.to_s.camelize.constantize.send(variable)
    klass.to_s.camelize.constantize.send("#{variable}=", value)
  end
  after(:each) do
    klass.to_s.camelize.constantize.send("#{variable}=", @nested_global_defaults[klass][variable].pop)
  end
end
