#TODO - write this test in the same form as the smaller test systems. 
#The code below is all old code from when I was debugging the system. Only here for reference when continuing to work on debugging initialization. 

#genTrip = GeneratorTrip(tripTime, PSY.get_component(PSY.DynamicInverter, sys, "GFM_Battery_31"))


#= using Revise
using PowerSystems
using PowerSimulationsDynamics
using Sundials
using PlotlyJS
using PowerFlows
using Logging
using DataFrames
using CSV
using OrdinaryDiffEq

const PSID = PowerSimulationsDynamics
const PSY = PowerSystems

# Params
tspan=(0.0, 5.0) # Time duration of simualtion (Not-ML)
tripTime = 0.1

# Build System
#sys = System(joinpath(pwd(), "PSCAD_144_BUS_EMT", "psid_files", "144Bus.json"))
#sys = System(joinpath(pwd(), "PSID_9_BUS_ALL_INVERTER", "9_bus_all_inverter.json"))
sys = System(joinpath(@__DIR__, "psid_files", "9bus.json"))
##
#csv_file = joinpath(pwd(), "PSCAD_144_BUS_EMT", "results", "initialization", "144bus_init.csv")
#csv_file = joinpath(pwd(), "PSCAD_144_BUS_EMT", "results", "initialization", "9bus_gens.csv")
csv_file = joinpath(pwd(), "PSCAD_144_BUS_EMT", "results", "initialization", "9bus_init.csv")
csv_file = joinpath(pwd(), "PSCAD_144_BUS_EMT", "results", "GFM_Battery_2.csv")

gentrip =  GeneratorTrip(tripTime,  get_component(DynamicInjection,sys , "GFM_Battery_2"))

##
sim = Simulation(
        MassMatrixModel,
        sys,
        pwd(),
        tspan,
        gentrip,
        all_lines_dynamic = true,
    )

# Run Small Signal Analysis
#sm = small_signal_analysis(sim)
# Show eigenvalue statistics summary_eigenvalues(sm)
# Run Perturbation
execute!(sim, Rodas5P(), abstol = 1e-9, reltol = 1e-9)
results = read_results(sim)

##
sim = Simulation(
        ResidualModel,
        sys,
        pwd(),
        tspan,
        gentrip,
        all_lines_dynamic = true,
    )
# Run Small Signal Analysis
#sm = small_signal_analysis(sim)
# Show eigenvalue statistics summary_eigenvalues(sm)
# Run Perturbation
execute!(sim, IDA(), abstol = 1e-9, reltol = 1e-9)
results = read_results(sim)
##
pscad_results = CSV.read(csv_file, DataFrame)

p1 = PlotlyJS.scatter()
traces = GenericTrace{Dict{Symbol, Any}}[]
for i in get_number.(get_components(Bus, sys))
    p1 = PlotlyJS.scatter(x = pscad_results[!, :time], y = pscad_results[!, "v_Bus_$i"], name = "PSCAD_v_$i")
    t, voltage = get_voltage_magnitude_series(results, i)
    p2 = PlotlyJS.scatter(x = t, y = voltage, name = "PSID_v_$i")
    push!(traces, p1, p2)
end
PlotlyJS.plot(traces)
##

iv_1 = sim.problem.f.f.cache.inner_vars[1:24]
iv_2 = sim.problem.f.f.cache.inner_vars[25:48]
iv_1[8]
sim.problem.f.f.inputs.dynamic_injectors
println("pscad results first droop:")
println("I_flt_d: ", Statistics.mean(pscad_results[!,"I_flt_dq:1"][end-100:end]))
println("I_flt_q: ", Statistics.mean(pscad_results[!,"I_flt_dq:2"][end-100:end]))
println("V_flt_d: ", Statistics.mean(pscad_results[!,"V_flt_dq:1"][end-100:end]))
println("V_flt_q: ", Statistics.mean(pscad_results[!,"V_flt_dq:2"][end-100:end]))
println("I_cnv_d: ", Statistics.mean(pscad_results[!,"I_cnv_dq:1"][end-100:end]))
println("I_cnv_q: ", Statistics.mean(pscad_results[!,"I_cnv_dq:2"][end-100:end]))
println("V_cnv_d: ", Statistics.mean(pscad_results[!,"V_cnv_dq:1"][end-100:end]))
println("V_cnv_q: ", Statistics.mean(pscad_results[!,"V_cnv_dq:2"][end-100:end]))


println("pscad results second droop:")
println("I_flt_d: ", Statistics.mean(pscad_results[!,"I_flt_dq_1:1"][end-100:end]))
println("I_flt_q: ", Statistics.mean(pscad_results[!,"I_flt_dq_1:2"][end-100:end]))
println("V_flt_d: ", Statistics.mean(pscad_results[!,"V_flt_dq_1:1"][end-100:end]))
println("V_flt_q: ", Statistics.mean(pscad_results[!,"V_flt_dq_1:2"][end-100:end]))
println("I_cnv_d: ", Statistics.mean(pscad_results[!,"I_cnv_dq_1:1"][end-100:end]))
println("I_cnv_q: ", Statistics.mean(pscad_results[!,"I_cnv_dq_1:2"][end-100:end]))
println("V_cnv_d: ", Statistics.mean(pscad_results[!,"V_cnv_dq_1:1"][end-100:end]))
println("V_cnv_q: ", Statistics.mean(pscad_results[!,"V_cnv_dq_1:2"][end-100:end]))


PlotlyJS.plot(pscad_results[!,"I_flt_dq:1"])
PlotlyJS.plot(pscad_results[!,"I_flt_dq:2"])
PlotlyJS.plot(pscad_results[!,"I_cnv_dq:1"])
PlotlyJS.plot(pscad_results[!,"I_cnv_dq:2"])
PlotlyJS.plot(pscad_results[!,"V_flt_dq:1"])
PlotlyJS.plot(pscad_results[!,"V_flt_dq:2"])
PlotlyJS.plot(pscad_results[!,"V_cnv_dq_1:1"][1:end])
PlotlyJS.plot(pscad_results[!,"V_cnv_dq_1:2"][1:end])
##
println("pscad results first gen:")
println("V_d: ", Statistics.mean(pscad_results[!,"V_dq:1"][end-100:end]))
println("V_q: ", Statistics.mean(pscad_results[!,"V_dq:2"][end-100:end]))
println("V_mag: ", sqrt(Statistics.mean(pscad_results[!,"V_dq:2"][end-100:end])^2 +  Statistics.mean(pscad_results[!,"V_dq:1"][end-100:end])^2))
println("I_d: ", Statistics.mean(pscad_results[!,"I_dq:1"][end-100:end]))
println("I_q: ", Statistics.mean(pscad_results[!,"I_dq:2"][end-100:end]))

println("pscad results second gen:yy")
println("V_d: ", Statistics.mean(pscad_results[!,"V_dq_1:1"][end-100:end]))
println("V_q: ", Statistics.mean(pscad_results[!,"V_dq_1:2"][end-100:end]))
println("V_mag: ", sqrt(Statistics.mean(pscad_results[!,"V_dq_1:2"][end-100:end])^2 +  Statistics.mean(pscad_results[!,"V_dq_1:1"][end-100:end])^2))
PlotlyJS.plot(pscad_results[!,"tau_m"])
println("I_d: ", Statistics.mean(pscad_results[!,"I_dq_1:1"][end-100:end]))
println("I_q: ", Statistics.mean(pscad_results[!,"I_dq_1:2"][end-100:end]))

println("pscad results third gen:")
println("V_d: ", Statistics.mean(pscad_results[!,"V_dq_2:1"][end-100:end]))
println("V_q: ", Statistics.mean(pscad_results[!,"V_dq_2:2"][end-100:end]))
println("V_mag: ", sqrt(Statistics.mean(pscad_results[!,"V_dq_2:2"][end-100:end])^2 +  Statistics.mean(pscad_results[!,"V_dq_2:1"][end-100:end])^2))

println("I_d: ", Statistics.mean(pscad_results[!,"I_dq_2:1"][end-100:end]))
println("I_q: ", Statistics.mean(pscad_results[!,"I_dq_2:2"][end-100:end]))


sim.problem.f.f.inputs.dynamic_injectors
iv_1 = sim.problem.f.f.cache.inner_vars[end-24:end-1]

println("tau_m1: ", Statistics.mean(pscad_results[!,"tau_m"][end-100:end]))
println("tau_e1: ", Statistics.mean(pscad_results[!,"tau_e"][end-100:end]))
println("tau_m2: ", Statistics.mean(pscad_results[!,"tau_m_1"][end-100:end]))
println("tau_e2: ", Statistics.mean(pscad_results[!,"tau_e_1"][end-100:end]))
println("tau_m3: ", Statistics.mean(pscad_results[!,"tau_m_2"][end-100:end]))
println("tau_e4: ", Statistics.mean(pscad_results[!,"tau_e_2"][end-100:end]))
println("Vf_1: ", Statistics.mean(pscad_results[!,"V_f"][end-100:end]))
println("Vf_2: ", Statistics.mean(pscad_results[!,"V_f_1"][end-100:end]))
println("Vf_3: ", Statistics.mean(pscad_results[!,"V_f_2"][end-100:end]))
##
traces = GenericTrace{Dict{Symbol, Any}}[]
p1 = PlotlyJS.scatter(x = pscad_results[!, :time], y = pscad_results[!, "V_cnv_abc_kV_active:1"], name = "active_a")
p2 = PlotlyJS.scatter(x = pscad_results[!, :time], y = pscad_results[!, "V_cnv_abc_kV_init:1"], name = "init_a")
p3 = PlotlyJS.scatter(x = pscad_results[!, :time], y = pscad_results[!, "V_cnv_abc_kV_active:2"], name = "active_b")
p4 = PlotlyJS.scatter(x = pscad_results[!, :time], y = pscad_results[!, "V_cnv_abc_kV_init:2"], name = "init_b")
p5 = PlotlyJS.scatter(x = pscad_results[!, :time], y = pscad_results[!, "V_cnv_abc_kV_active:3"], name = "active_c")
p6 = PlotlyJS.scatter(x = pscad_results[!, :time], y = pscad_results[!, "V_cnv_abc_kV_init:3"], name = "init_c")
push!(traces, p1, p2, p3, p4, p5, p6)
PlotlyJS.plot(traces)

##
include(joinpath(pwd(), "PSID2PSCAD", "_pscad_psid_conversion","simulation_extras.jl"))
traces = GenericTrace{Dict{Symbol, Any}}[]
for d in get_components(DynamicInjection, sys)
    scale_pscad = get_base_power(d) /100.0
    psid_name = get_name(d)
    pscad_name =  pscad_compat_name(psid_name)
    p1 = PlotlyJS.scatter(x = pscad_results[!, :time], y = scale_pscad .* pscad_results[!, "P_$pscad_name"], name = "PSCAD_$pscad_name")
    t, P = get_activepower_series(results, psid_name)
    p2 = PlotlyJS.scatter(x = t, y = P, name = "P_$psid_name")
    push!(traces, p1, p2)
end
PlotlyJS.plot(traces)
##
traces = GenericTrace{Dict{Symbol, Any}}[]
for d in get_components(DynamicInjection, sys)
    scale_pscad = get_base_power(d) /100.0
    scale_psid = 100.0/get_base_power(d)
    psid_name = get_name(d)
    pscad_name =  pscad_compat_name(psid_name)
    p1 = PlotlyJS.scatter(x = pscad_results[!, :time], y =  pscad_results[!, "Q_$pscad_name"], name = "PSCAD_$pscad_name")
    t, P = get_reactivepower_series(results, psid_name)
    p2 = PlotlyJS.scatter(x = t, y = P .* scale_psid, name = "Q_$psid_name")
    push!(traces, p1, p2)
end
PlotlyJS.plot(traces)
##
traces = GenericTrace{Dict{Symbol, Any}}[]
for d in get_components(DynamicInjection, sys)
    if typeof(d) !== DynamicInverter{AverageConverter, OuterControl{ActivePowerPI, ReactivePowerPI}, CurrentModeControl, FixedDCSource, KauraPLL, LCLFilter}
        psid_name = get_name(d)
        pscad_name =  pscad_compat_name(psid_name)
        p1 = PlotlyJS.scatter(x = pscad_results[!, :time], y =  pscad_results[!, "f_$pscad_name"], name = "PSCAD_$pscad_name")
        t, f = get_frequency_series(results, psid_name)
        p2 = PlotlyJS.scatter(x = t, y = f, name = "f_$psid_name")
        push!(traces, p1, p2)
    end 
end
PlotlyJS.plot(traces) =#


