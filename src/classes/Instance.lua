Instance = {
	cpu = {},
	mem = {},
	conf = {},
	stat = {},
}

rv.instance = {}

function Instance:new (o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	o.cpu[1] = Cpu:new()
	o.cpu[1].conf.ref_instance = o

	o.mem = Mem:new()

	o.cpu[1].ref_mem = o.mem

	return o
end

function Instance:del (o)
	rv.instance[o.id] = nil
	self = nil
end
