require 'singleton'

class Type
  def gen_code(mod:)
    raise NotImplementedError
  end
end

class Int32Type < Type
  include Singleton

  def gen_code(mod:)
    LLVMInt32Type()
  end
end

class StringType < Type
  include Singleton

  def gen_code(mod:)
    LLVMPointerType(LLVMInt8Type(), 0)
  end
end
