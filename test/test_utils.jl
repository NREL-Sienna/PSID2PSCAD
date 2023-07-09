function export_inner_vars(sim)
    inner_vars = sim.problem.f.f.cache.inner_vars
    iv_map = PSID.make_inner_vars_map(sim.inputs)
    output_map = Dict()
    for (k, d_map) in iv_map
        output_map[k] = Dict()
        for (state, ix) in d_map
            output_map[k][state] = inner_vars[ix]
        end
    end
    return output_map
end

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


function plot_psid_pscad_initialization_comparison(sys, psid_results, pscad_results_initialization, psid_inner_vars)
    p = PlotlyJS.make_subplots(
        rows = 8,
        cols = 2,
        specs = [PlotlyJS.Spec() PlotlyJS.Spec(); PlotlyJS.Spec() PlotlyJS.Spec();  PlotlyJS.Spec() PlotlyJS.Spec();  PlotlyJS.Spec() PlotlyJS.Spec();  PlotlyJS.Spec() PlotlyJS.Spec();  PlotlyJS.Spec() PlotlyJS.Spec(); PlotlyJS.Spec() PlotlyJS.Spec(); PlotlyJS.Spec() PlotlyJS.Spec()],
        subplot_titles = ["V" "P" "Q" "F" "V_flt_d"  "V_flt_q"  "V_cnv_d"  "V_cnv_q" "I_flt_d"  "I_flt_q"  "I_cnv_d"  "I_cnv_q" "Vd" "Vq" "Id" "Iq"],
        vertical_spacing = 0.04, 
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

    for d in collect(get_components(DynamicInjection, sys))
        scale_pscad = get_base_power(d) /100.0
        psid_name = get_name(d)
        pscad_name =  pscad_compat_name(psid_name)
        t, P = get_activepower_series(psid_results, psid_name)
        t, Q = get_reactivepower_series(psid_results, psid_name)
        t, f = get_frequency_series(psid_results, psid_name)    #this errors 
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(; x = pscad_results_initialization[!, :time], y = pscad_results_initialization[!, "P_$pscad_name"] ./ 100.0, name = "PSCAD_$pscad_name"),
            row = 1,
            col = 2,
        )
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(x = [t[1], pscad_results_initialization[!, :time][end]], y = [P[1], P[1]], marker_color =:black, name = "PSID_$psid_name"),
            row = 1,
            col = 2,
        )
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(; x = pscad_results_initialization[!, :time], y = pscad_results_initialization[!, "Q_$pscad_name"] ./ 100.0, name = "PSCAD_$pscad_name"),
            row = 2,
            col = 1,
        )
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(x = [t[1], pscad_results_initialization[!, :time][end]], y = [Q[1], Q[1]], marker_color =:black, name = "PSID_$psid_name"),
            row = 2,
            col = 1,
        )
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
    for d in collect(get_components(DynamicGenerator, sys))
        scale_pscad = get_base_power(d) /100.0
        psid_name = get_name(d)
        pscad_name =  pscad_compat_name(psid_name)

        V_tR = psid_inner_vars[psid_name][PowerSimulationsDynamics.VR_gen_var]
        V_tI = psid_inner_vars[psid_name][PowerSimulationsDynamics.VI_gen_var]
        t, _ = get_state_series(psid_results, (psid_name, :δ))
        δ = get_state_series(psid_results, (psid_name, :δ))[2][1]
        Xd_pp = PSY.get_Xd_pp(PSY.get_machine(d))
        Xq_pp = PSY.get_Xq_pp(PSY.get_machine(d))
        γ_d1 = PSY.get_γ_d1(PSY.get_machine(d))
        γ_q1 = PSY.get_γ_q1(PSY.get_machine(d))
        ed_p =  get_state_series(psid_results, (psid_name, :ed_p))[2][1]
        eq_p =  get_state_series(psid_results, (psid_name, :eq_p))[2][1]
        ψd =  get_state_series(psid_results, (psid_name, :ψd))[2][1]
        ψq =  get_state_series(psid_results, (psid_name, :ψq))[2][1]
        ψd_pp =  get_state_series(psid_results, (psid_name, :ψd_pp))[2][1]
        ψq_pp =  get_state_series(psid_results, (psid_name, :ψq_pp))[2][1]

        #4 psid values to compare:
        V_dq_psid = PSID.ri_dq(δ) * [V_tR; V_tI]
        i_d_psid = (1.0 / Xd_pp) * (γ_d1 * eq_p - ψd + (1 - γ_d1) * ψd_pp)      #15.15
        i_q_psid = (1.0 / Xq_pp) * (-γ_q1 * ed_p - ψq + (1 - γ_q1) * ψq_pp)     #15.15

        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(; x = pscad_results_initialization[!, :time], y =  pscad_results_initialization[!, "Vd_$pscad_name"], name = "PSCAD_$pscad_name"),
            row = 7,
            col = 1,
        )
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(x = [t[1], pscad_results_initialization[!, :time][end]], y = [V_dq_psid[1], V_dq_psid[1]], marker_color =:black, name = "PSID_$psid_name"),
            row = 7,
            col = 1,
        )
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(; x = pscad_results_initialization[!, :time], y =  pscad_results_initialization[!, "Vq_$pscad_name"], name = "PSCAD_$pscad_name"),
            row = 7,
            col = 2,
        )
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(x = [t[1], pscad_results_initialization[!, :time][end]], y = [V_dq_psid[2], V_dq_psid[2]], marker_color =:black, name = "PSID_$psid_name"),
            row = 7,
            col = 2,
        )
         PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(; x = pscad_results_initialization[!, :time], y =  pscad_results_initialization[!, "Id_$pscad_name"], name = "PSCAD_$pscad_name"),
            row = 8,
            col = 1,
        )
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(x = [t[1], pscad_results_initialization[!, :time][end]], y = [i_d_psid, i_d_psid], marker_color =:black, name = "PSID_$psid_name"),
            row = 8,
            col = 1,
        )
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(; x = pscad_results_initialization[!, :time], y =  pscad_results_initialization[!, "Iq_$pscad_name"], name = "PSCAD_$pscad_name"),
            row = 8,
            col = 2,
        )
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(x = [t[1], pscad_results_initialization[!, :time][end]], y = [i_q_psid, i_q_psid], marker_color =:black, name = "PSID_$psid_name"),
            row = 8,
            col = 2,
        )
    end 

    for d in collect(get_components(DynamicInverter, sys))
        scale_pscad = get_base_power(d) /100.0
        psid_name = get_name(d)
        pscad_name =  pscad_compat_name(psid_name)
        t, _ = get_state_series(psid_results, (psid_name, :ir_filter))

        Ir_filter_psid = get_state_series(psid_results, (psid_name, :ir_filter))[2][1]
        Ii_filter_psid = get_state_series(psid_results, (psid_name, :ii_filter))[2][1]
        Ir_cnv_psid = get_state_series(psid_results, (psid_name, :ir_cnv))[2][1]
        Ii_cnv_psid = get_state_series(psid_results, (psid_name, :ii_cnv))[2][1]
        Vr_filter_psid = psid_inner_vars[psid_name][PowerSimulationsDynamics.Vr_filter_var]
        Vi_filter_psid = psid_inner_vars[psid_name][PowerSimulationsDynamics.Vi_filter_var]
        Vr_cnv_psid = psid_inner_vars[psid_name][PowerSimulationsDynamics.Vr_cnv_var]
        Vi_cnv_psid = psid_inner_vars[psid_name][PowerSimulationsDynamics.Vi_cnv_var]
        θ_oc = psid_inner_vars[psid_name][PowerSimulationsDynamics.θ_oc_var]
        #Here are the eight psid values. 
        I_flt_dq_psid = PSID.ri_dq(θ_oc + pi / 2) * [Ir_filter_psid; Ii_filter_psid]
        I_cnv_dq_psid = PSID.ri_dq(θ_oc + pi / 2) * [Ir_cnv_psid; Ii_cnv_psid]
        V_flt_dq_psid = PSID.ri_dq(θ_oc + pi / 2) * [Vr_filter_psid; Vi_filter_psid]
        V_cnv_dq_psid = PSID.ri_dq(θ_oc + pi / 2) * [Vr_cnv_psid; Vi_cnv_psid]

        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(; x = pscad_results_initialization[!, :time], y =  pscad_results_initialization[!, "V_flt_d_$pscad_name"], name = "PSCAD_$pscad_name"),
            row = 3,
            col = 1,
        )
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(x = [t[1], pscad_results_initialization[!, :time][end]], y = [V_flt_dq_psid[1], V_flt_dq_psid[1]], marker_color =:black, name = "PSID_$psid_name"),
            row = 3,
            col = 1,
        )
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(; x = pscad_results_initialization[!, :time], y =  pscad_results_initialization[!, "V_flt_q_$pscad_name"], name = "PSCAD_$pscad_name"),
            row = 3,
            col = 2,
        )
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(x = [t[1], pscad_results_initialization[!, :time][end]], y = [V_flt_dq_psid[2], V_flt_dq_psid[2]], marker_color =:black, name = "PSID_$psid_name"),
            row = 3,
            col = 2,
        )
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(; x = pscad_results_initialization[!, :time], y =  pscad_results_initialization[!, "V_cnv_d_$pscad_name"], name = "PSCAD_$pscad_name"),
            row = 4,
            col = 1,
        )
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(x = [t[1], pscad_results_initialization[!, :time][end]], y = [V_cnv_dq_psid[1], V_cnv_dq_psid[1]], marker_color =:black, name = "PSID_$psid_name"),
            row = 4,
            col = 1,
        )
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(; x = pscad_results_initialization[!, :time], y =  pscad_results_initialization[!, "V_cnv_q_$pscad_name"], name = "PSCAD_$pscad_name"),
            row = 4,
            col = 2,
        )
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(x = [t[1], pscad_results_initialization[!, :time][end]], y = [V_cnv_dq_psid[2], V_cnv_dq_psid[2]], marker_color =:black, name = "PSID_$psid_name"),
            row = 4,
            col = 2,
        )
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(; x = pscad_results_initialization[!, :time], y =  pscad_results_initialization[!, "I_flt_d_$pscad_name"], name = "PSCAD_$pscad_name"),
            row = 5,
            col = 1,
        )
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(x = [t[1], pscad_results_initialization[!, :time][end]], y = [I_flt_dq_psid[1], I_flt_dq_psid[1]], marker_color =:black, name = "PSID_$psid_name"),
            row = 5,
            col = 1,
        )
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(; x = pscad_results_initialization[!, :time], y =  pscad_results_initialization[!, "I_flt_q_$pscad_name"], name = "PSCAD_$pscad_name"),
            row = 5,
            col = 2,
        )
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(x = [t[1], pscad_results_initialization[!, :time][end]], y = [I_flt_dq_psid[2], I_flt_dq_psid[2]], marker_color =:black, name = "PSID_$psid_name"),
            row = 5,
            col = 2,
        )
         PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(; x = pscad_results_initialization[!, :time], y =  pscad_results_initialization[!, "I_cnv_d_$pscad_name"], name = "PSCAD_$pscad_name"),
            row = 6,
            col = 1,
        )
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(x = [t[1], pscad_results_initialization[!, :time][end]], y = [I_cnv_dq_psid[1], I_cnv_dq_psid[1]], marker_color =:black, name = "PSID_$psid_name"),
            row = 6,
            col = 1,
        )
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(; x = pscad_results_initialization[!, :time], y =  pscad_results_initialization[!, "I_cnv_q_$pscad_name"], name = "PSCAD_$pscad_name"),
            row = 6,
            col = 2,
        )
        PlotlyJS.add_trace!(
            p,
            PlotlyJS.scatter(x = [t[1], pscad_results_initialization[!, :time][end]], y = [I_cnv_dq_psid[2], I_cnv_dq_psid[2]], marker_color =:black, name = "PSID_$psid_name"),
            row = 6,
            col = 2,
        )
    end 
    return p 
end 

function psid_pscad_initialization_comparison(sys, psid_results, pscad_results_initialization, psid_inner_vars)
    for bus in get_components(Bus, sys)
        bus_number = get_number(bus)
        bus_name = get_name(bus)
        t_psid, voltage_psid = get_voltage_magnitude_series(psid_results, bus_number)
        voltage_pscad  = pscad_results_initialization[!, "v_$bus_name"]
        res_V = voltage_psid[1] .- voltage_pscad[end]
        #@test LinearAlgebra.norm(res_V) / length(res_V) <= 2e-4
    end
    for d in get_components(DynamicInjection, sys)
        scale_pscad = get_base_power(d) /100.0
        psid_name = get_name(d)
        pscad_name =  pscad_compat_name(psid_name)
        _, P_psid = get_activepower_series(psid_results, psid_name)
        _, Q_psid = get_reactivepower_series(psid_results, psid_name)
       # _, f_psid = get_frequency_series(psid_results, psid_name)
        P_pscad = pscad_results_initialization[!, "P_$pscad_name"] ./ 100.0
        Q_pscad = pscad_results_initialization[!, "Q_$pscad_name"] ./ 100.0
        #f_pscad = pscad_results_initialization[!, "f_$pscad_name"]
        res_P = P_psid[1] .- P_pscad[end]
        res_Q = Q_psid[end] .- Q_pscad[end]
        #res_f = f_psid[end] .- f_pscad[end]
        #@test LinearAlgebra.norm(res_P) / length(res_P) <= 8e-5
        #@test LinearAlgebra.norm(res_Q) / length(res_f) <= 2e-2  #TODO - tighten bounds when Q measurement is corrected
        #@test LinearAlgebra.norm(res_P) / length(res_P) <= 8e-5
    end 
    for d in get_components(DynamicGenerator, sys)

        scale_pscad = get_base_power(d) /100.0
        psid_name = get_name(d)
        pscad_name =  pscad_compat_name(psid_name)
        n_average = 100 

        V_tR = psid_inner_vars[psid_name][PowerSimulationsDynamics.VR_gen_var]
        V_tI = psid_inner_vars[psid_name][PowerSimulationsDynamics.VI_gen_var]
        t, _ = get_state_series(psid_results, (psid_name, :δ))
        δ = get_state_series(psid_results, (psid_name, :δ))[2][1]
        Xd_pp = PSY.get_Xd_pp(PSY.get_machine(d))
        Xq_pp = PSY.get_Xq_pp(PSY.get_machine(d))
        γ_d1 = PSY.get_γ_d1(PSY.get_machine(d))
        γ_q1 = PSY.get_γ_q1(PSY.get_machine(d))
        ed_p =  get_state_series(psid_results, (psid_name, :ed_p))[2][1]
        eq_p =  get_state_series(psid_results, (psid_name, :eq_p))[2][1]
        ψd =  get_state_series(psid_results, (psid_name, :ψd))[2][1]
        ψq =  get_state_series(psid_results, (psid_name, :ψq))[2][1]
        ψd_pp =  get_state_series(psid_results, (psid_name, :ψd_pp))[2][1]
        ψq_pp =  get_state_series(psid_results, (psid_name, :ψq_pp))[2][1]

        #4 psid values to compare:
        V_dq_psid = PSID.ri_dq(δ) * [V_tR; V_tI]

        I_d_psid = (1.0 / Xd_pp) * (γ_d1 * eq_p - ψd + (1 - γ_d1) * ψd_pp)      #15.15
        I_q_psid = (1.0 / Xq_pp) * (-γ_q1 * ed_p - ψq + (1 - γ_q1) * ψq_pp)     #15.15
        V_d_psid = V_dq_psid[1]
        V_q_psid = V_dq_psid[2]

        V_d_pscad = mean(pscad_results_initialization[!, "Vd_$pscad_name"][end-n_average:end])
        V_q_pscad = mean(pscad_results_initialization[!, "Vq_$pscad_name"][end-n_average:end])
        I_d_pscad = mean(pscad_results_initialization[!, "Id_$pscad_name"][end-n_average:end])
        I_q_pscad = mean(pscad_results_initialization[!, "Iq_$pscad_name"][end-n_average:end])

        @show V_d_psid - V_d_pscad
        @show V_q_psid - V_q_pscad
        @show I_d_psid - I_d_pscad
        @show I_q_psid - I_q_pscad
        println()

    end

    for d in get_components(DynamicInverter, sys)
        scale_pscad = get_base_power(d) /100.0
        psid_name = get_name(d)
        pscad_name =  pscad_compat_name(psid_name)
        n_average = 100 
        I_flt_d_pscad = mean(pscad_results_initialization[!, "I_flt_d_$pscad_name"][end-n_average:end])
        I_flt_q_pscad = mean(pscad_results_initialization[!, "I_flt_q_$pscad_name"][end-n_average:end])
        I_cnv_d_pscad = mean(pscad_results_initialization[!, "I_cnv_d_$pscad_name"][end-n_average:end])
        I_cnv_q_pscad = mean(pscad_results_initialization[!, "I_cnv_q_$pscad_name"][end-n_average:end])
        V_flt_d_pscad = mean(pscad_results_initialization[!, "V_flt_d_$pscad_name"][end-n_average:end])
        V_flt_q_pscad = mean(pscad_results_initialization[!, "V_flt_q_$pscad_name"][end-n_average:end])
        V_cnv_d_pscad = mean(pscad_results_initialization[!, "V_cnv_d_$pscad_name"][end-n_average:end])
        V_cnv_d_pscad = mean(pscad_results_initialization[!, "V_cnv_d_$pscad_name"][end-n_average:end])
        V_cnv_q_pscad = mean(pscad_results_initialization[!, "V_cnv_q_$pscad_name"][end-n_average:end])

        Ir_filter_psid = get_state_series(psid_results, (psid_name, :ir_filter))[2][1]
        Ii_filter_psid = get_state_series(psid_results, (psid_name, :ii_filter))[2][1]
        Ir_cnv_psid = get_state_series(psid_results, (psid_name, :ir_cnv))[2][1]
        Ii_cnv_psid = get_state_series(psid_results, (psid_name, :ii_cnv))[2][1]
        Vr_filter_psid = psid_inner_vars[psid_name][PowerSimulationsDynamics.Vr_filter_var]
        Vi_filter_psid = psid_inner_vars[psid_name][PowerSimulationsDynamics.Vi_filter_var]
        Vr_cnv_psid = psid_inner_vars[psid_name][PowerSimulationsDynamics.Vr_cnv_var]
        Vi_cnv_psid = psid_inner_vars[psid_name][PowerSimulationsDynamics.Vi_cnv_var]
        θ_oc = psid_inner_vars[psid_name][PowerSimulationsDynamics.θ_oc_var]
        I_flt_dq_psid = PSID.ri_dq(θ_oc + pi / 2) * [Ir_filter_psid; Ii_filter_psid]
        I_cnv_dq_psid = PSID.ri_dq(θ_oc + pi / 2) * [Ir_cnv_psid; Ii_cnv_psid]
        V_flt_dq_psid = PSID.ri_dq(θ_oc + pi / 2) * [Vr_filter_psid; Vi_filter_psid]
        V_cnv_dq_psid = PSID.ri_dq(θ_oc + pi / 2) * [Vr_cnv_psid; Vi_cnv_psid]

        I_flt_d_psid = I_flt_dq_psid[1]
        I_flt_q_psid = I_flt_dq_psid[2]
        I_cnv_d_psid = I_cnv_dq_psid[1]
        I_cnv_q_psid = I_cnv_dq_psid[2]

        V_flt_d_psid = V_flt_dq_psid[1]
        V_flt_q_psid = V_flt_dq_psid[2]
        V_cnv_d_psid = V_cnv_dq_psid[1]
        V_cnv_q_psid = V_cnv_dq_psid[2]

        @show I_flt_q_psid - I_flt_q_pscad
        @show I_flt_d_psid - I_flt_d_pscad
        @show I_cnv_q_psid - I_cnv_q_pscad
        @show I_cnv_d_psid - I_cnv_d_pscad

        @show V_flt_q_psid - V_flt_q_pscad
        @show V_flt_d_psid - V_flt_d_pscad
        @show V_cnv_q_psid - V_cnv_q_pscad
        @show V_cnv_d_psid - V_cnv_d_pscad
        println()
        #@test LinearAlgebra.norm(res_I_flt_d) / length(res_I_flt_d) <= 8e-5
        #@test LinearAlgebra.norm(res_I_flt_q) / length(res_I_flt_q) <= 8e-5
    end

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
            PlotlyJS.scatter(; x = pscad_results_initialization[!, :time], y = pscad_results_initialization[!, "P_$pscad_name"] ./ 100.0, name = "PSCAD_$pscad_name"),
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
            PlotlyJS.scatter(; x = pscad_results_initialization[!, :time], y = pscad_results_initialization[!, "Q_$pscad_name"] ./ 100.0, name = "PSCAD_$pscad_name"),
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
        P_pscad = pscad_results_initialization[!, "P_$pscad_name"] ./ 100.0
        Q_pscad = pscad_results_initialization[!, "Q_$pscad_name"] ./ 100.0
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



