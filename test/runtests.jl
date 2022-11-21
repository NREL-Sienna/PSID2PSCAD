using Test
using Revise
include(joinpath(@__DIR__, "..", "case_3bus", "psid_files", "dynamic_test_data.jl"))
include(joinpath(@__DIR__, "..", "_pscad_psid_conversion", "PSCAD_PSID.jl"))
include(joinpath(@__DIR__, "..", "_pscad_psid_conversion", "collect_data.jl"))
include(joinpath(@__DIR__, "..", "constants.jl"))
include(joinpath(pwd(), "PSCAD", "case_3bus", "scripts", "run_psid.jl"))
include(joinpath(pwd(), "PSCAD", "case_3bus", "scripts", "run_pscad.jl"))
# Issue with path in windows per: https://github.com/JuliaPy/PyCall.jl/issues/730
ENV["PATH"] = Conda.bin_dir(Conda.ROOTENV) * ";" * ENV["PATH"]

#Set build PyCall to use the pscadV5 python environment (name of environment could change)
ENV["PYTHON"] = PYTHON_PATH
Pkg.build("PyCall")

#import python packages
mhi = pyimport("mhi.pscad")
sys = pyimport("sys")
logging = pyimport("logging")
os = pyimport("os")
time = pyimport("time")
win32 = pyimport("win32com.shell")

#add PSCAD_Python library directory to path
pyimport("sys")."path"
pushfirst!(PyVector(pyimport("sys")."path"), joinpath("PSCAD", "_pscad_psid_conversion"))
PP = pyimport("PSCAD_Python")

function read_csv_file_to_dataframe(file::AbstractString)
    return open(file, "r") do io
        CSV.read(io, DataFrame)
    end
end
function get_zoom_plot(series, tmin, tmax)
    return [
        (series[1][ix], series[2][ix]) for
        (ix, s) in enumerate(series[1]) if (s > tmin && s < tmax)
    ]
end
include(joinpath(@__DIR__, "test_psid_paper_3bus.jl"))
#TODO - add more tests for machine/mixed devices 
