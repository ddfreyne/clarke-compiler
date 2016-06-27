class Env
  def initialize(parent: nil, contents: {})
    @parent = parent
    @contents = contents
  end

  def key?(key)
    @contents.key?(key) || (@parent && @parent.key?(key))
  end

  def fetch(key, expr: nil)
    if @parent
      @contents.fetch(key) { @parent.fetch(key, expr: expr) }
    else
      @contents.fetch(key) { raise NameError.new(key, expr) }
    end
  end

  def []=(key, value)
    @contents[key] = value
  end

  def push(contents = {})
    self.class.new(parent: self, contents: contents)
  end
end
