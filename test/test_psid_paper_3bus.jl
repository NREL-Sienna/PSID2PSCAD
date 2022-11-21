#@testset "psid_paper_3bus_all_inverters" begin

sys, result_psid = run_3bus_psid(
    rawfile = "ThreeBusPSCAD.raw",
    perturbation_type = "LoadStepDown",    #Options: ["LoadStepDown" "LoadStepUp" "LineTrip"]
    line_to_trip = "BUS 1-BUS 2-i_1",
    line_type = "Dynamic",
    bus_1_device = "vsm",
    bus_2_device = "droop",
    saveat = 5e-5,
    tspan = (0.0, 10.0),
    ref_bus_number = 101,
    frequency_reference = "ReferenceBus", #["ConstantFrequency, "ConstantFrequency"]
    solver = "Rodas5",
    abstol = 1e-14,
)
record_3bus_psid(
    result_psid;
    recorded_voltages = [101, 102, 103],   # Bus numbers to record voltage  
    recorded_states = [], #[("generator-101-1", :θ_pll)]
    recorded_P = ["generator-102-1"],
    recorded_Q = ["generator-102-1"],
    recorded_ω = ["generator-102-1"],
    output_csv_name = "psid_output",
)
run_3bus_pscad(
    sys;
    t_GEN = 2.0, #release time for generators 
    t_INV = 5.0, #release time for inverters 
    perturbation_type = "LoadStepDown",  #Op,tions: ["LoadStepDown" "LoadStepUp" "LineTrip"]  
    pscad_workspace = "workspace_3bus.pswx",
    pscad_case = "case_3bus",           #the pscad case corresponding to the psid test
    t_offset = 10.0,                    #only collect data starting at t_offset
    saveat = 5e-5,
    time_step = 5e-6,
    t_span = (0.0, 10.0),
    output_csv_name = "pscad_output",
)

function compare_traces(
    pscad_df,
    psid_df,
    tstart,
    tend,
    toffset,
    pscad_signal,
    psid_signal;
    display_plot = false,
)
    signal_psid = [
        x[2] for x in get_zoom_plot(
            [psid_result[!, "time"], psid_result[!, psid_signal]],
            tstart,
            tend,
        )
    ]
    t_psid = [
        x[1] for x in get_zoom_plot(
            [psid_result[!, "time"], psid_result[!, psid_signal]],
            tstart,
            tend,
        )
    ]
    signal_pscad = [
        x[2] for x in get_zoom_plot(
            [pscad_result[!, "time"] .- toffset, pscad_result[!, pscad_signal]],
            tstart,
            tend,
        )
    ]
    t_pscad = [
        x[1] for x in get_zoom_plot(
            [pscad_result[!, "time"] .- toffset, pscad_result[!, pscad_signal]],
            tstart,
            tend,
        )
    ]
    if display_plot == true
        p1 = plot(t_psid, signal_psid, label = "PSID-- $(psid_signal)")
        display(plot!(p1, t_pscad, signal_pscad, label = "PSCAD-- $(pscad_signal)"))
    end
    @assert LinearAlgebra.norm(t_psid - round.(t_pscad, digits = 6)) == 0.0
    return LinearAlgebra.norm(signal_psid .- signal_pscad, Inf),
    LinearAlgebra.norm(signal_psid .- signal_pscad, 2)
end

psid_result = read_csv_file_to_dataframe(
    joinpath(pwd(), "PSCAD", "case_3bus", "psid_files", "psid_output.csv"),
)
pscad_result = read_csv_file_to_dataframe(
    joinpath(pwd(), "PSCAD", "case_3bus", "pscad_files", "pscad_output.csv"),
)

inf_norm, two_norm = compare_traces(
    pscad_result,
    psid_result,
    0.09,
    0.11,
    10.0,
    "P_102",
    "P_generator-102-1";
    display_plot = true,
)
@test inf_norm <= 0.0076
@test two_norm <= 0.11

inf_norm, two_norm = compare_traces(
    pscad_result,
    psid_result,
    0.0,
    1.0,
    10.0,
    "f_out_102",
    "ω_generator-102-1";
    display_plot = true,
)
@test inf_norm <= 2.3e-5
@test two_norm <= 0.0021
