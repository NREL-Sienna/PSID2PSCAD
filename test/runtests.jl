using Revise
using Pkg
using Conda
using CSV
using DataFrames
using LinearAlgebra
using PlotlyJS
using PowerSystems
using PowerSimulationsDynamics
using PyCall
using OrdinaryDiffEq
using Statistics 
using Sundials
using Test
using Logging
const PSY = PowerSystems
const PSID = PowerSimulationsDynamics

include("data_tests/dynamic_test_data.jl")
include("data_tests/bus_details.jl")
include("test_utils.jl")

include(joinpath(pwd(), "PSID2PSCAD", "_pscad_psid_conversion", "build_system.jl"))
include(joinpath(pwd(), "PSID2PSCAD", "_pscad_psid_conversion", "parameterize_system.jl"))
include(joinpath(pwd(), "PSID2PSCAD", "_pscad_psid_conversion", "simulation_extras.jl"))
include(joinpath(pwd(), "PSID2PSCAD", "_pscad_psid_conversion", "collect_data.jl"))


PYTHON_PATH = "C:\\Users\\Matt Bossart\\.conda\\envs\\pscad_v5\\python.exe"

#Issue with path in windows per: https://github.com/JuliaPy/PyCall.jl/issues/730
ENV["PATH"] = Conda.bin_dir(Conda.ROOTENV) * ";" * ENV["PATH"]  

#Set build PyCall to use the environment specified in PYTHON_PATH
ENV["PYTHON"] = PYTHON_PATH
Pkg.build("PyCall")

#Import python packages
mhi = pyimport("mhi.pscad")
sys = pyimport("sys")
logging = pyimport("logging")
os = pyimport("os")
time = pyimport("time")
win32 = pyimport("win32com.shell")

#Add PSCAD_Python library directory to system path
pyimport("sys")."path"
pushfirst!(PyVector(pyimport("sys")."path"), joinpath("PSID2PSCAD", "_pscad_psid_conversion"))
PP = pyimport("PSCAD_Python")

logger = PSY.configure_logging(;
    console_level = Logging.Warn,  # Logging.Error, Logging.Debug
    file_level =  Logging.Warn,
)
with_logger(logger) do
    #include("test_psid_paper.jl")            #3bus system with all inverters
    #include("test_three_bus_inv_gen.jl")    #3bus system with inverter and machine - this should work as is without further changes 
    include("test_nine_bus_inv_gen.jl")                                         #9bus system with multiple devices per bus - need to add sources to ensure good PF match   
                                             #144bus system - should be same as 9 bus, no additional changes needed 
end     
flush(logger)
close(logger)

