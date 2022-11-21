#= using DataFrames
using CSV
using Arrow
namespace = "ieee_14_bus_GM2022_pi"
pscad_output_folder_path =
    joinpath(pwd(), "cases", "ieee_14_bus_GM2022", string(namespace, ".gf46"))

df1 = collect_pscad_outputs(pscad_output_folder_path)

open(joinpath(pwd(), "test_arrow"), "w") do io
    Arrow.write(io, df1)
end
 =#
#Returns a vector of dataframes, where each dataframe corresponds to a simulation either standalone or in a volley
function collect_pscad_outputs(pscad_output_folder_path)
    dfs = []
    inf_files =
        filter(x -> endswith(x, ".inf"), readdir(pscad_output_folder_path, join = true))
    for inf_file in inf_files
        @info "setup file", basename(inf_file)
        signal_names = []
        open(inf_file) do file
            for ln in eachline(file)
                a = split(ln)
                @assert a[3][6] == '"'
                push!(signal_names, a[3][7:(end - 1)])   #fix hardcode 
                @assert a[3][end] == '"'
            end
        end
        signal_names = vcat("time", signal_names)
        @info "signal names", signal_names
        all_output_files =
            filter(x -> endswith(x, ".out"), readdir(pscad_output_folder_path, join = true))

        out_files =
            filter(x -> contains(x, split(basename(inf_file), ".")[1]), all_output_files)
        @info "output file names" basename.(out_files)
        df = DataFrame()
        for (i, out_file) in enumerate(out_files)
            path = joinpath(pscad_output_folder_path, out_file)
            df_temp = DataFrame(
                CSV.File(
                    path;
                    delim = ' ',
                    ignorerepeated = true,
                    types = Float64,
                    skipto = 2,
                ),
            )
            (i !== 1) && (df_temp = df_temp[!, 2:end])
            df = hcat(df, df_temp, makeunique = true)
        end
        rename!(df, Symbol.(signal_names), makeunique = true)
        push!(dfs, df)
    end
    return dfs
end
