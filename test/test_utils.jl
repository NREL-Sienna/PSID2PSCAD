function _compute_total_load_parameters(load::PSY.StandardLoad)
    # Constant Power Data
    constant_active_power = PSY.get_constant_active_power(load)
    constant_reactive_power = PSY.get_constant_reactive_power(load)
    max_constant_active_power = PSY.get_max_constant_active_power(load)
    max_constant_reactive_power = PSY.get_max_constant_reactive_power(load)
    # Constant Current Data
    current_active_power = PSY.get_current_active_power(load)
    current_reactive_power = PSY.get_current_reactive_power(load)
    max_current_active_power = PSY.get_max_current_active_power(load)
    max_current_reactive_power = PSY.get_max_current_reactive_power(load)
    # Constant Admittance Data
    impedance_active_power = PSY.get_impedance_active_power(load)
    impedance_reactive_power = PSY.get_impedance_reactive_power(load)
    max_impedance_active_power = PSY.get_max_impedance_active_power(load)
    max_impedance_reactive_power = PSY.get_max_impedance_reactive_power(load)
    # Total Load Calculations
    active_power = constant_active_power + current_active_power + impedance_active_power
    reactive_power =
        constant_reactive_power + current_reactive_power + impedance_reactive_power
    max_active_power =
        max_constant_active_power + max_current_active_power + max_impedance_active_power
    max_reactive_power =
        max_constant_reactive_power +
        max_current_reactive_power +
        max_impedance_reactive_power
    return active_power, reactive_power, max_active_power, max_reactive_power
end

function transform_load_to_constant_impedance(load::PSY.StandardLoad)
    # Total Load Calculations
    active_power, reactive_power, max_active_power, max_reactive_power =
        _compute_total_load_parameters(load)
    # Set Impedance Power
    PSY.set_impedance_active_power!(load, active_power)
    PSY.set_impedance_reactive_power!(load, reactive_power)
    PSY.set_max_impedance_active_power!(load, max_active_power)
    PSY.set_max_impedance_reactive_power!(load, max_reactive_power)
    # Set everything else to zero
    PSY.set_constant_active_power!(load, 0.0)
    PSY.set_constant_reactive_power!(load, 0.0)
    PSY.set_max_constant_active_power!(load, 0.0)
    PSY.set_max_constant_reactive_power!(load, 0.0)
    PSY.set_current_active_power!(load, 0.0)
    PSY.set_current_reactive_power!(load, 0.0)
    PSY.set_max_current_active_power!(load, 0.0)
    PSY.set_max_current_reactive_power!(load, 0.0)
    return
end

function transform_all_lines_dynamic_except_one!(sys::System, line_to_leave::String)
    @assert get_component(Line,sys, line_to_leave ) !== nothing 
    for b in get_components(Line, sys)
        if get_name(b) != line_to_trip
            dyn_branch = PowerSystems.DynamicBranch(b)
            add_component!(sys, dyn_branch)
        end
    end
end 


function plot_psid_pscad_initialization_comparison(sys, psid_results, pscad_results_initialization)
    p = PlotlyJS.make_subplots(
        rows = 2,
        cols = 2,
        specs = [PlotlyJS.Spec() PlotlyJS.Spec(); PlotlyJS.Spec() PlotlyJS.Spec()],
        subplot_titles = ["V" "P" "Q" "F"],
    )
    traces = GenericTrace{Dict{Symbol, Any}}[]
    for bus in get_components(Bus, sys)
        bus_number = get_number(bus)
        bus_name = get_name(bus)
        t, voltage = get_voltage_magnitude_series(psid_results, bus_number)
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(; x = pscad_results_initialization[!, :time], y = pscad_results_initialization[!, "v_$bus_name"], name = "PSCAD_$bus_number"),
            row = 1,
            col = 1,
        )
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(x = [t[1], pscad_results_initialization[!, :time][end]], y = [voltage[1], voltage[1]], marker_color =:black, name = "PSID_$bus_number"),
            row = 1,
            col = 1,
        )
    end
    for d in get_components(DynamicInjection, sys)
        scale_pscad = get_base_power(d) /100.0
        psid_name = get_name(d)
        pscad_name =  pscad_compat_name(psid_name)
        t, P = get_activepower_series(psid_results, psid_name)
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(; x = pscad_results_initialization[!, :time], y = pscad_results_initialization[!, "P_$pscad_name"], name = "PSCAD_$pscad_name"),
            row = 1,
            col = 2,
        )
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(x = [t[1], pscad_results_initialization[!, :time][end]], y = [P[1], P[1]], marker_color =:black, name = "PSID_$psid_name"),
            row = 1,
            col = 2,
        )
    end
    for d in get_components(DynamicInjection, sys)
        scale_pscad = get_base_power(d) /100.0
        psid_name = get_name(d)
        pscad_name =  pscad_compat_name(psid_name)
        t, Q = get_reactivepower_series(psid_results, psid_name)
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(; x = pscad_results_initialization[!, :time], y = pscad_results_initialization[!, "Q_$pscad_name"], name = "PSCAD_$pscad_name"),
            row = 2,
            col = 1,
        )
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(x = [t[1], pscad_results_initialization[!, :time][end]], y = [Q[1], Q[1]], marker_color =:black, name = "PSID_$psid_name"),
            row = 2,
            col = 1,
        )
    end
    for d in get_components(DynamicInjection, sys)
        scale_pscad = get_base_power(d) /100.0
        psid_name = get_name(d)
        pscad_name =  pscad_compat_name(psid_name)
        t, f = get_frequency_series(psid_results, psid_name)
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(; x = pscad_results_initialization[!, :time], y = pscad_results_initialization[!, "f_$pscad_name"], name = "PSCAD_$pscad_name"),
            row = 2,
            col = 2,
        )
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(x = [t[1], pscad_results_initialization[!, :time][end]], y = [f[1], f[1]], marker_color =:black, name = "PSID_$psid_name"),
            row = 2,
            col = 2,
        )
    end
    return p 
end 

function psid_pscad_initialization_comparison(sys, psid_results, pscad_results_initialization)
    for bus in get_components(Bus, sys)
        bus_number = get_number(bus)
        bus_name = get_name(bus)
        t_psid, voltage_psid = get_voltage_magnitude_series(psid_results, bus_number)
        voltage_pscad  = pscad_results_initialization[!, "v_$bus_name"]
        res_V = voltage_psid[1] .- voltage_pscad[end]
        @test LinearAlgebra.norm(res_V) / length(res_V) <= 2e-4
    end
    for d in get_components(DynamicInjection, sys)
        scale_pscad = get_base_power(d) /100.0
        psid_name = get_name(d)
        pscad_name =  pscad_compat_name(psid_name)
        _, P_psid = get_activepower_series(psid_results, psid_name)
        _, Q_psid = get_reactivepower_series(psid_results, psid_name)
        _, f_psid = get_frequency_series(psid_results, psid_name)
        P_pscad = pscad_results_initialization[!, "P_$pscad_name"]
        Q_pscad = pscad_results_initialization[!, "Q_$pscad_name"]
        f_pscad = pscad_results_initialization[!, "f_$pscad_name"]
        res_P = P_psid[1] .- P_pscad[end]
        res_Q = Q_psid[end] .- Q_pscad[end]
        res_f = f_psid[end] .- f_pscad[end]
        @test LinearAlgebra.norm(res_P) / length(res_P) <= 8e-5
        @test LinearAlgebra.norm(res_Q) / length(res_f) <= 2e-2 #TODO - tighten bounds when Q measurement is corrected
        @test LinearAlgebra.norm(res_P) / length(res_P) <= 8e-5
    end
    return 
end 

function plot_psid_pscad_fault_comparison(sys, psid_results, pscad_results_initialization)
    p = PlotlyJS.make_subplots(
        rows = 2,
        cols = 2,
        specs = [PlotlyJS.Spec() PlotlyJS.Spec(); PlotlyJS.Spec() PlotlyJS.Spec()],
        subplot_titles = ["V" "P" "Q" "F"],
    )
    traces = GenericTrace{Dict{Symbol, Any}}[]
    for bus in get_components(Bus, sys)
        bus_number = get_number(bus)
        bus_name = get_name(bus)
        t, voltage = get_voltage_magnitude_series(psid_results, bus_number)
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(; x = pscad_results_initialization[!, :time], y = pscad_results_initialization[!, "v_$bus_name"], name = "PSCAD_$bus_number"),
            row = 1,
            col = 1,
        )
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(x = t, y = voltage, marker_color =:black, name = "PSID_$bus_number"),
            row = 1,
            col = 1,
        )
    end
    for d in get_components(DynamicInjection, sys)
        scale_pscad = get_base_power(d) /100.0
        psid_name = get_name(d)
        pscad_name =  pscad_compat_name(psid_name)
        t, P = get_activepower_series(psid_results, psid_name)
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(; x = pscad_results_initialization[!, :time], y = pscad_results_initialization[!, "P_$pscad_name"], name = "PSCAD_$pscad_name"),
            row = 1,
            col = 2,
        )
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(x = t, y = P, marker_color =:black, name = "PSID_$psid_name"),
            row = 1,
            col = 2,
        )
    end
    for d in get_components(DynamicInjection, sys)
        scale_pscad = get_base_power(d) /100.0
        psid_name = get_name(d)
        pscad_name =  pscad_compat_name(psid_name)
        t, Q = get_reactivepower_series(psid_results, psid_name)
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(; x = pscad_results_initialization[!, :time], y = pscad_results_initialization[!, "Q_$pscad_name"], name = "PSCAD_$pscad_name"),
            row = 2,
            col = 1,
        )
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(x = t, y = Q, marker_color =:black, name = "PSID_$psid_name"),
            row = 2,
            col = 1,
        )
    end
    for d in get_components(DynamicInjection, sys)
        scale_pscad = get_base_power(d) /100.0
        psid_name = get_name(d)
        pscad_name =  pscad_compat_name(psid_name)
        t, f = get_frequency_series(psid_results, psid_name)
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(; x = pscad_results_initialization[!, :time], y = pscad_results_initialization[!, "f_$pscad_name"], name = "PSCAD_$pscad_name"),
            row = 2,
            col = 2,
        )
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(x = t, y = f, marker_color =:black, name = "PSID_$psid_name"),
            row = 2,
            col = 2,
        )
    end
    return p 
end 

function psid_pscad_fault_comparison(sys, psid_results, pscad_results_initialization)
    for bus in get_components(Bus, sys)
        bus_number = get_number(bus)
        bus_name = get_name(bus)
        t_psid, voltage_psid = get_voltage_magnitude_series(psid_results, bus_number)
        voltage_pscad  = pscad_results_initialization[!, "v_$bus_name"]
        #res_V = voltage_psid[1] .- voltage_pscad[end]
        res_V = voltage_psid .- voltage_pscad
        @test LinearAlgebra.norm(res_V) / length(res_V) <= 2e-4
    end
    for d in get_components(DynamicInjection, sys)
        scale_pscad = get_base_power(d) /100.0
        psid_name = get_name(d)
        pscad_name =  pscad_compat_name(psid_name)
        _, P_psid = get_activepower_series(psid_results, psid_name)
        _, Q_psid = get_reactivepower_series(psid_results, psid_name)
        _, f_psid = get_frequency_series(psid_results, psid_name)
        P_pscad = pscad_results_initialization[!, "P_$pscad_name"]
        Q_pscad = pscad_results_initialization[!, "Q_$pscad_name"]
        f_pscad = pscad_results_initialization[!, "f_$pscad_name"]
        res_P = P_psid .- P_pscad
        res_Q = Q_psid .- Q_pscad
        res_f = f_psid .- f_pscad
        @test LinearAlgebra.norm(res_P) / length(res_P) <= 8e-5
        @test LinearAlgebra.norm(res_Q) / length(res_f) <= 2e-2 #TODO - tighten bounds when Q measurement is corrected
        @test LinearAlgebra.norm(res_P) / length(res_P) <= 8e-5
    end
    return 
end 



