local RV = {}

-- definition constants
RV.MAX_MEMORY_WORD = 65536 -- 256 kiB limit
RV.MAX_MEMORY_SIZE = RV.MAX_MEMORY_WORD * 4
RV.MAX_FREQ_MULTIPLIER = 34 -- default_frame_rate * 34 <= logisim_max_simulation_hertz
RV.MAX_TEMPERATURE = 120.0
RV.MOD_IDENTIFIER = "FREECOMPUTER"
RV.EXTENSIONS = {"RV32I", "RV32C", "RV32M"}
RV.ILLEGAL_INSTRUCTION = "ILLEGAL"

return RV
