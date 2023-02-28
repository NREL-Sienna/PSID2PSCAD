function set_project_parameters!(project; kwargs...)
    project_params = project.parameters()
    for k in kwargs
        project_params[string(k[1])] = k[2]
    end
    PP.update_parameter_by_dictionary(project, project_params)
end

function _add_to_enabled_gens_layer(
    g::DynamicInverter{
        AverageConverter,
        OuterControl{VirtualInertia, ReactivePowerDroop},
        VoltageModeControl,
        FixedDCSource,
        KauraPLL,
        LCLFilter,
    },
    project,
)
    psid_name = get_name(g)
    project.find("PSID_Library_Inverters:DARCO_VSM", psid_name).add_to_layer("enabled_gens")
end

function _add_to_enabled_gens_layer(
    g::DynamicInverter{
        AverageConverter,
        OuterControl{ActivePowerDroop, ReactivePowerDroop},
        VoltageModeControl,
        FixedDCSource,
        FixedFrequency,
        LCLFilter,
    },
    project,
)
    psid_name = get_name(g)
    project.find("PSID_Library_Inverters:DROOP_GFM", psid_name).add_to_layer("enabled_gens")
end

function _add_to_enabled_gens_layer(
    g::DynamicInverter{
        AverageConverter,
        OuterControl{ActivePowerPI, ReactivePowerPI},
        CurrentModeControl,
        FixedDCSource,
        ReducedOrderPLL,
        LCLFilter,
    },
    project,
)
    psid_name = get_name(g)
    project.find("PSID_Library_Inverters:GFL", psid_name).add_to_layer("enabled_gens")
end

function _add_to_enabled_gens_layer(
    g::DynamicGenerator{SauerPaiMachine, SingleMass, SEXS, GasTG, IEEEST},
    project,
)
    psid_name = get_name(g)
    project.find("PSID_Library_Inverters:SAUERPAI_SEXS_GASTG_IEEEST", psid_name).add_to_layer("enabled_gens")
end

function _add_to_enabled_gens_layer(
    g::DynamicGenerator{SauerPaiMachine, SingleMass, SEXS, GasTG, PSSFixed},
    project,
)
    psid_name = get_name(g)
    project.find("PSID_Library_Inverters:SAUERPAI_SEXS_GASTG_PSSFIXED", psid_name).add_to_layer("enabled_gens")
end

function _add_to_enabled_gens_layer(
    g::DynamicGenerator{SauerPaiMachine, SingleMass, SEXS, HydroTurbineGov, IEEEST},
    project,
)
    psid_name = get_name(g)
    project.find("PSID_Library_Inverters:SAUERPAI_SEXS_HYGOV_IEEEST", psid_name).add_to_layer("enabled_gens")
end

function _add_to_enabled_gens_layer(
    g::DynamicGenerator{SauerPaiMachine, SingleMass, SEXS, HydroTurbineGov, PSSFixed},
    project,
)
    psid_name = get_name(g)
    project.find("PSID_Library_Inverters:SAUERPAI_SEXS_HYGOV_PSSFIXED", psid_name).add_to_layer("enabled_gens")
end

function _add_to_enabled_gens_layer(
    g::DynamicGenerator{SauerPaiMachine, SingleMass, SEXS, SteamTurbineGov1, IEEEST},
    project,
)
    psid_name = get_name(g)
    project.find("PSID_Library_Inverters:SAUERPAI_SEXS_TGOV1_IEEEST", psid_name).add_to_layer("enabled_gens")
end

function _add_to_enabled_gens_layer(
    g::DynamicGenerator{SauerPaiMachine, SingleMass, SEXS, SteamTurbineGov1, PSSFixed},
    project,
)
    psid_name = get_name(g)
    project.find("PSID_Library_Inverters:SAUERPAI_SEXS_TGOV1_PSSFIXED", psid_name).add_to_layer("enabled_gens")
end

function _add_to_enabled_gens_layer(
    g::DynamicGenerator{SauerPaiMachine, SingleMass, AVRFixed, TGFixed, PSSFixed},
    project,
)
    psid_name = get_name(g)
    project.find("PSID_Library_Inverters:FIXED_SAUER_PAI", psid_name).add_to_layer(
        "enabled_gens",
    )
    #project.find("PSID_Library_Inverters:SIMPLE_MACHINE", psid_name).add_to_layer("enabled_gens")           #SWITCH HERE TO DECIDE WHICH MACHINE MODEL 
end

function _add_to_enabled_gens_layer(g::Source, project)
    psid_name = get_name(g)
    project.find("PSID_Library_Inverters:INFINITE_BUS", psid_name).add_to_layer(
        "enabled_gens",
    )
end

function enable_dynamic_injection_by_type(sys, project)
    for g in get_components(DynamicInjection, sys)
        psid_name = get_name(g)
        for f in project.find_all(psid_name)
            f.add_to_layer("disabled_gens")
        end
        _add_to_enabled_gens_layer(g, project)
    end
    for g in get_components(Source, sys)
        psid_name = get_name(g)
        for f in project.find_all(psid_name)
            f.add_to_layer("disabled_gens")
        end
        _add_to_enabled_gens_layer(g, project)
    end
end

function build_system(sys::System, project, coorDict; add_line_breakers = false, add_multimeters = false)
    components = collect(get_components(Component, sys))
    main = project.user_canvas("Main")
    for c in components
        @info "building component: $(get_name(c)) of type $(typeof(c))"
        build_component(c, get_name(c), main, coorDict, sys; add_line_breakers, add_multimeters)
    end
end

bus_length_const = 6
function build_component(psid_component::Bus, pscad_component_name, pscad_canvas, coorDict, sys; add_line_breakers = false, add_multimeters = false)
    BusDict = Dict()
    for (key, value) in coorDict
        if value.orientation == "tall"
            BusDict[key] = (value.centerpoint[1], value.centerpoint[2] - bus_length_const), (value.centerpoint[1], value.centerpoint[2] + bus_length_const)
        elseif value.orientation == "wide"
            BusDict[key] = (value.centerpoint[1] - bus_length_const, value.centerpoint[2]), (value.centerpoint[1] + bus_length_const, value.centerpoint[2])
        else
            @error "error: not tall or wide"
        end
    end
    new_bus = pscad_canvas.create_bus(
        BusDict[pscad_component_name][1],
        BusDict[pscad_component_name][2],
    )
    new_bus.parameters(Name = pscad_component_name)

    if add_multimeters == true
        if coorDict[pscad_component_name].orientation == "tall"
            multimeter_offset_x = 2
            multimeter_offset_y = 5 
        else    
            multimeter_offset_x = 6
            multimeter_offset_y = 1 
        end
        new_multi = pscad_canvas.add_component(
            "master",
            "multimeter",
            coorDict[pscad_component_name].centerpoint[1] + multimeter_offset_x,
            coorDict[pscad_component_name].centerpoint[2] + multimeter_offset_y
            )
        multi_name = "m_"*pscad_component_name
        new_multi.set_parameters(
            Name = multi_name,
            #RMS = "YES, ANALOG",
            #MeasPh = "YES, RADIANS",
            #Vrms = "v_"*pscad_component_name,
            #Ph = "theta_"*pscad_component_name
            )
        new_wire = pscad_canvas.add_wire(new_multi.get_port_location("A"), coorDict[pscad_component_name].centerpoint)
    end
end

function build_component(
    psid_component::DynamicGenerator{
        SauerPaiMachine,
        SingleMass,
        SEXS,
        SteamTurbineGov1,
        PSSFixed,
    },
    pscad_component_name,
    pscad_canvas,
    coorDict,
    sys;
    add_line_breakers = false,
    add_multimeters = false
)
    static_injector = get_component(StaticInjection, sys, pscad_component_name)
    Busname = get_name(get_bus(static_injector))
    if coorDict[Busname].devices_location == "s"
        new_mach = pscad_canvas.add_component(
            "PSID_Library_Inverters",
            "SAUERPAI_SEXS_TGOV1_PSSFIXED",
            coorDict[Busname].centerpoint[1] - 10,
            coorDict[Busname].centerpoint[2] + 7,
        )
    elseif coorDict[Busname].devices_location == "n"
        new_mach = pscad_canvas.add_component(
            "PSID_Library_Inverters",
            "SAUERPAI_SEXS_TGOV1_PSSFIXED",
            coorDict[Busname].centerpoint[1] - 10,
            coorDict[Busname].centerpoint[2] - 7,
        )
    elseif coorDict[Busname].devices_location == "e"
        new_mach = pscad_canvas.add_component(
            "PSID_Library_Inverters",
            "SAUERPAI_SEXS_TGOV1_PSSFIXED",
            coorDict[Busname].centerpoint[1] + 7,
            coorDict[Busname].centerpoint[2] + 10,
        )
    elseif coorDict[Busname].devices_location == "w"
        new_mach = pscad_canvas.add_component(
            "PSID_Library_Inverters",
            "SAUERPAI_SEXS_TGOV1_PSSFIXED",
            coorDict[Busname].centerpoint[1] - 7,
            coorDict[Busname].centerpoint[2] + 10,
        )
    else
        @error "No direction specified for component placement"
        println(Busname)
    end
    new_mach.set_parameters(Name = pscad_component_name)
    new_wire =
        pscad_canvas.create_wire(new_mach.get_port_location("POI"), coorDict[Busname][1])
end

function build_component(
    psid_component::DynamicInverter{
        AverageConverter,
        OuterControl{ActivePowerDroop, ReactivePowerDroop},
        VoltageModeControl,
        FixedDCSource,
        FixedFrequency,
        LCLFilter,
    },
    pscad_component_name,
    pscad_canvas,
    coorDict,
    sys;
    add_line_breakers = false, 
    add_multimeters = false
)
    static_injector = get_component(StaticInjection, sys, pscad_component_name)
    Busname = get_name(get_bus(static_injector))
    if coorDict[Busname].devices_location == "s"
        new_inv = pscad_canvas.add_component(
            "PSID_Library_Inverters",
            "DROOP_GFM",
            coorDict[Busname].centerpoint[1] - 3,
            coorDict[Busname].centerpoint[2] + 7,
        )
    elseif coorDict[Busname].devices_location == "n"
        new_inv = pscad_canvas.add_component(
            "PSID_Library_Inverters",
            "DROOP_GFM",
            coorDict[Busname].centerpoint[1] - 3,
            coorDict[Busname].centerpoint[2] - 7,
        )
    elseif coorDict[Busname].devices_location == "e"
        new_inv = pscad_canvas.add_component(
            "PSID_Library_Inverters",
            "DROOP_GFM",
            coorDict[Busname].centerpoint[1] + 7,
            coorDict[Busname].centerpoint[2] + 5,
        )
    elseif coorDict[Busname].devices_location == "w"
        new_inv = pscad_canvas.add_component(
            "PSID_Library_Inverters",
            "DROOP_GFM",
            coorDict[Busname].centerpoint[1] - 7,
            coorDict[Busname].centerpoint[2] + 5,
        )
    else
        @error "No direction specified for component placement"
        println(Busname)
    end
    new_inv.set_parameters(Name = pscad_component_name)
    new_wire =
        pscad_canvas.create_wire(new_inv.get_port_location("POI"), coorDict[Busname][1])
end

function build_component(
    psid_component::DynamicInverter{
        AverageConverter,
        OuterControl{ActivePowerPI, ReactivePowerPI},
        CurrentModeControl,
        FixedDCSource,
        KauraPLL,
        LCLFilter,
    },
    pscad_component_name,
    pscad_canvas,
    coorDict,
    sys; 
    add_line_breakers = false, 
    add_multimeters = false
)
    static_injector = get_component(StaticInjection, sys, pscad_component_name)
    Busname = get_name(get_bus(static_injector))
    if coorDict[Busname].devices_location == "s"
        new_inv = pscad_canvas.add_component(
            "PSID_Library_Inverters",
            "GFL_KAURA_PLL",
            coorDict[Busname].centerpoint[1] + 4,
            coorDict[Busname].centerpoint[2] + 7,
        )
    elseif coorDict[Busname].devices_location == "n"
        new_inv = pscad_canvas.add_component(
            "PSID_Library_Inverters",
            "GFL_KAURA_PLL",
            coorDict[Busname].centerpoint[1] + 4,
            coorDict[Busname].centerpoint[2] - 7,
        )
    elseif coorDict[Busname].devices_location == "e"
        new_inv = pscad_canvas.add_component(
            "PSID_Library_Inverters",
            "GFL_KAURA_PLL",
            coorDict[Busname].centerpoint[1] + 7,
            coorDict[Busname].centerpoint[2],
        )
    elseif coorDict[Busname].devices_location == "w"
        new_inv = pscad_canvas.add_component(
            "PSID_Library_Inverters",
            "GFL_KAURA_PLL",
            coorDict[Busname].centerpoint[1] - 7,
            coorDict[Busname].centerpoint[2],
        )
    else
        @error "No direction specified for component placement"
        println(Busname)
    end
    new_inv.set_parameters(Name = pscad_component_name)
    new_wire =
        pscad_canvas.create_wire(new_inv.get_port_location("POI"), coorDict[Busname][1])
end

function build_component(psid_component::Line, pscad_component_name, pscad_canvas, coorDict, sys; add_line_breakers = false, add_multimeters = false)
    split_parts = split(pscad_component_name, "-")
    midpoint =
        floor(Int, (coorDict[split_parts[1]].centerpoint[1] + coorDict[split_parts[2]].centerpoint[1]) / 2),
        floor(Int, (coorDict[split_parts[1]].centerpoint[2] + coorDict[split_parts[2]].centerpoint[2]) / 2)
    new_pi = pscad_canvas.add_component("master", "newpi", midpoint[1], midpoint[2])
    new_pi.set_parameters(Name = pscad_component_name)

    if add_line_breakers == true
        left_br_offset = -3
        right_br_offset = 3
        br_coors1 = (midpoint[1]+left_br_offset, midpoint[2])
        br_coors2 = (midpoint[1]+right_br_offset, midpoint[2])
        new_br1 = pscad_canvas.add_component(
            "master",
            "breaker3",
            br_coors1[1],
            br_coors1[2]
            )
        new_br2 = pscad_canvas.add_component(
            "master",
            "breaker3",
            br_coors2[1],
            br_coors2[2]
            )
        if coorDict[split_parts[2]].centerpoint[1] > coorDict[split_parts[1]].centerpoint[1]
            new_wire3 = pscad_canvas.add_wire(coorDict[split_parts[1]].centerpoint, new_br1.get_port_location("N2"))
            new_wire4 = pscad_canvas.add_wire(coorDict[split_parts[2]].centerpoint, new_br2.get_port_location("N1"))
        elseif coorDict[split_parts[2]].centerpoint[1] < coorDict[split_parts[1]].centerpoint[1] 
            new_wire3 = pscad_canvas.add_wire(coorDict[split_parts[2]].centerpoint, new_br1.get_port_location("N2"))
            new_wire4 = pscad_canvas.add_wire(coorDict[split_parts[1]].centerpoint, new_br2.get_port_location("N1"))
        else 
            bus1_left_end = (coorDict[split_parts[1]].centerpoint[1]-bus_length_const, coorDict[split_parts[1]].centerpoint[2])
            bus2_right_end = (coorDict[split_parts[2]].centerpoint[1]+bus_length_const, coorDict[split_parts[2]].centerpoint[2])
            new_wire3 = pscad_canvas.add_wire(bus1_left_end, new_br1.get_port_location("N2")) 
            new_wire4 = pscad_canvas.add_wire(bus2_right_end, new_br2.get_port_location("N1"))
        end
    else
        if coorDict[split_parts[2]].centerpoint[1] > coorDict[split_parts[1]].centerpoint[1]
            new_wire =
            pscad_canvas.add_wire(new_pi.get_port_location("N2"), coorDict[split_parts[2]].centerpoint)
            new_wire2 =
            pscad_canvas.add_wire(new_pi.get_port_location("N1"), coorDict[split_parts[1]].centerpoint)
        else
            new_wire =
            pscad_canvas.add_wire(new_pi.get_port_location("N1"), coorDict[split_parts[2]].centerpoint)
            new_wire2 =
            pscad_canvas.add_wire(new_pi.get_port_location("N2"), coorDict[split_parts[1]].centerpoint)
        end
    end
end

function build_component(
    psid_component::Transformer2W,
    pscad_component_name,
    pscad_canvas,
    coorDict,
    sys; 
    add_line_breakers = false, 
    add_multimeters = false
)
    split_parts = split(pscad_component_name, "-")
    midpoint =
        floor(Int, (coorDict[split_parts[1]].centerpoint[1] + coorDict[split_parts[2]].centerpoint[1]) / 2),
        floor(Int, (coorDict[split_parts[1]].centerpoint[2] + coorDict[split_parts[2]].centerpoint[2]) / 2)
    new_xfmr = pscad_canvas.add_component("master", "xfmr-3p2w", midpoint[1], midpoint[2])
    new_xfmr.set_parameters(Name = pscad_component_name)
    if coorDict[split_parts[2]].centerpoint[1] > coorDict[split_parts[1]].centerpoint[1]
        new_wire =
        pscad_canvas.add_wire(new_xfmr.get_port_location("N2"), coorDict[split_parts[2]].centerpoint)
        new_wire2 =
        pscad_canvas.add_wire(new_xfmr.get_port_location("N1"), coorDict[split_parts[1]].centerpoint)
    else
        new_wire =
        pscad_canvas.add_wire(new_xfmr.get_port_location("N1"), coorDict[split_parts[2]].centerpoint)
        new_wire2 =
        pscad_canvas.add_wire(new_xfmr.get_port_location("N2"), coorDict[split_parts[1]].centerpoint)
    end
end

function build_component(
    psid_component::PowerLoad,
    pscad_component_name,
    pscad_canvas,
    coorDict,
    sys; 
    add_line_breakers = false, 
    add_multimeters = false
)
    loadbus = get_name(get_bus(psid_component))
    new_load = pscad_canvas.add_component(
        "master",
        "fixed_load",
        coorDict[loadbus].centerpoint[1] + 2,
        coorDict[loadbus].centerpoint[2] + 2,
    )
    new_load.set_parameters(Name = pscad_component_name)
    new_wire =
        pscad_canvas.create_wire(new_load.get_port_location("IA"), coorDict[loadbus][1])
end

function build_component(psid_component::Arc, pscad_component_name, pscad_canvas, coorDict, sys; add_line_breakers = false, add_multimeters = false)
    @info "Skipping build for type Arc"
end

function build_component(
    psid_component::LoadZone,
    pscad_component_name,
    pscad_canvas,
    coorDict,
    sys; 
    add_line_breakers = false, 
    add_multimeters = false
)
    @info "Skipping build for type LoadZone"
end

function build_component(psid_component::Area, pscad_component_name, pscad_canvas, coorDict, sys; add_line_breakers = false, add_multimeters = false)
    @info "Skipping build for type Area"
end

function build_component(
    psid_component::GenericBattery,
    pscad_component_name,
    pscad_canvas,
    coorDict,
    sys; 
    add_line_breakers = false, 
    add_multimeters = false
)
    @info "Skipping build for type GenericBattery"
end

function build_component(
    psid_component::ThermalStandard,
    pscad_component_name,
    pscad_canvas,
    coorDict,
    sys; 
    add_line_breakers = false, 
    add_multimeters = false
)
    @info "Skipping build for type ThermalStandard"
end

function parameterize_system(sys::System, project)
    sim = Simulation!(MassMatrixModel, sys, pwd(), (0.0, 0.0))
    ss = small_signal_analysis(sim)
    @warn ss.stable
    x0_dict = read_initial_conditions(sim)
    setpoints_dict = get_setpoints(sim)

    thermal = collect(get_components(ThermalStandard, sys))
    for t in thermal
        @info "writing ThermalStandard initial conditions: $(get_name(t))"
        write_initial_conditions(t, get_name(t), project, x0_dict)
    end

    injectors = collect(get_components(DynamicInjection, sys))
    for i in injectors
        @info "writing DynamicInjection initial conditions and setpoints: $(get_name(i))"
        write_setpoints(i, get_name(i), project, setpoints_dict)
        write_initial_conditions(i, get_name(i), project, x0_dict)
    end

    buses = collect(get_components(Bus, sys))
    for b in buses
        @info "writing Bus initial conditions and setpoints: $(get_name(b))"
        write_initial_conditions(b, get_name(b), project, x0_dict)
    end

    components = collect(get_components(Component, sys))
    for c in components
        @info "writing Component parameters: $(get_name(c)) of type $(typeof(c))"
        write_parameters(c, get_name(c), project)
    end
end

function write_parameters!(pscad_params, filter::LCLFilter)
    pscad_params["lf"] = get_lf(filter)
    pscad_params["rf"] = get_rf(filter)
    pscad_params["cf"] = get_cf(filter)
    pscad_params["lg"] = get_lg(filter)
    pscad_params["rg"] = get_rg(filter)
end

function write_parameters!(pscad_params, active_power::VirtualInertia)
    pscad_params["Ta"] = get_Ta(active_power)
    pscad_params["kd"] = get_kd(active_power)
    pscad_params["k_omega"] = get_kω(active_power)
end

function write_parameters!(pscad_params, active_power::ActivePowerDroop)
    pscad_params["Rp"] = get_Rp(active_power)
    pscad_params["omega_z"] = get_ωz(active_power)
end

function write_parameters!(pscad_params, active_power::ActivePowerPI)
    pscad_params["Kp_p"] = get_Kp_p(active_power)
    pscad_params["Ki_p"] = get_Ki_p(active_power)
    pscad_params["omega_z"] = get_ωz(active_power)
end

function write_parameters!(pscad_params, reactive_power::ReactivePowerPI)
    pscad_params["Kp_q"] = get_Kp_q(reactive_power)
    pscad_params["Ki_q"] = get_Ki_q(reactive_power)
    pscad_params["omega_f"] = get_ωf(reactive_power)
end

function write_parameters!(pscad_params, reactive_power::ReactivePowerDroop)
    pscad_params["kq"] = get_kq(reactive_power)
    pscad_params["omega_f"] = get_ωf(reactive_power)
end

function write_parameters!(
    pscad_params,
    outer_control::OuterControl{VirtualInertia, ReactivePowerDroop},
)
    active_power = get_active_power(outer_control)
    write_parameters!(pscad_params, active_power)
    reactive_power = get_reactive_power(outer_control)
    write_parameters!(pscad_params, reactive_power)
end

function write_parameters!(
    pscad_params,
    outer_control::OuterControl{ActivePowerDroop, ReactivePowerDroop},
)
    active_power = get_active_power(outer_control)
    write_parameters!(pscad_params, active_power)
    reactive_power = get_reactive_power(outer_control)
    write_parameters!(pscad_params, reactive_power)
end

function write_parameters!(
    pscad_params,
    outer_control::OuterControl{ActivePowerPI, ReactivePowerPI},
)
    active_power = get_active_power(outer_control)
    write_parameters!(pscad_params, active_power)
    reactive_power = get_reactive_power(outer_control)
    write_parameters!(pscad_params, reactive_power)
end

function write_parameters!(pscad_params, converter::AverageConverter) end

function write_parameters!(pscad_params, inner_control::VoltageModeControl)
    pscad_params["kpv"] = get_kpv(inner_control)
    pscad_params["kiv"] = get_kiv(inner_control)
    pscad_params["kffv"] = get_kffv(inner_control)
    pscad_params["rv"] = get_rv(inner_control)
    pscad_params["lv"] = get_lv(inner_control)
    pscad_params["kpc"] = get_kpc(inner_control)
    pscad_params["kic"] = get_kic(inner_control)
    pscad_params["kffi"] = get_kffi(inner_control)
    pscad_params["omega_ad"] = get_ωad(inner_control)
    pscad_params["kad"] = get_kad(inner_control)
end

function write_parameters!(pscad_params, inner_control::CurrentModeControl)
    pscad_params["kpc"] = get_kpc(inner_control)
    pscad_params["kic"] = get_kic(inner_control)
    pscad_params["kffv"] = get_kffv(inner_control)
end

function write_parameters!(pscad_params, dc_source::FixedDCSource)
    pscad_params["voltage"] = get_voltage(dc_source)
end

function write_parameters!(pscad_params, freq_estimator::FixedFrequency) end

function write_parameters!(pscad_params, freq_estimator::KauraPLL)
    pscad_params["omega_lp"] = get_ω_lp(freq_estimator)
    pscad_params["kp_pll"] = get_kp_pll(freq_estimator)
    pscad_params["ki_pll"] = get_ki_pll(freq_estimator)
end

function write_parameters!(pscad_params, freq_estimator::ReducedOrderPLL)
    pscad_params["omega_lp"] = get_ω_lp(freq_estimator)
    pscad_params["kp_pll"] = get_kp_pll(freq_estimator)
    pscad_params["ki_pll"] = get_ki_pll(freq_estimator)
end

function write_parameters!(pscad_params, machine::RoundRotorQuadratic)
    @warn "Saturation not considered in machine"
    pscad_params["Ra"] = get_R(machine)
    pscad_params["Tdo_"] = get_Td0_p(machine)
    pscad_params["Tdo__"] = get_Td0_pp(machine)
    pscad_params["Tqo_"] = get_Tq0_p(machine)
    pscad_params["Tqo__"] = get_Tq0_pp(machine)
    pscad_params["Xd"] = get_Xd(machine)
    pscad_params["Xq"] = get_Xq(machine)
    pscad_params["Xd_"] = get_Xd_p(machine)
    pscad_params["Xq_"] = get_Xq_p(machine)
    pscad_params["Xd__"] = get_Xd_pp(machine)
    pscad_params["Xq__"] = get_Xd_pp(machine) #Xd_pp = Xq_pp for round rotor 
    pscad_params["Xp"] = get_Xl(machine)  #Xl = Xp if Airgap factor = 1 
end

function write_parameters!(pscad_params, machine::SauerPaiMachine)
    @warn "Saturation not considered in SauerPai machine"
    pscad_params["machine_R"] = get_R(machine)
    pscad_params["machine_Td0_p"] = get_Td0_p(machine)
    pscad_params["machine_Td0_pp"] = get_Td0_pp(machine)
    pscad_params["machine_Tq0_p"] = get_Tq0_p(machine)
    pscad_params["machine_Tq0_pp"] = get_Tq0_pp(machine)
    pscad_params["machine_Xd"] = get_Xd(machine)
    pscad_params["machine_Xq"] = get_Xq(machine)
    pscad_params["machine_Xd_p"] = get_Xd_p(machine)
    pscad_params["machine_Xq_p"] = get_Xq_p(machine)
    pscad_params["machine_Xd_pp"] = get_Xd_pp(machine)
    pscad_params["machine_Xq_pp"] = get_Xq_pp(machine)
    pscad_params["machine_Xl"] = get_Xl(machine)  #Xl = Xp if Airgap factor = 1 
end

function write_parameters!(pscad_params, shaft::SingleMass)
    pscad_params["shaft_H"] = get_H(shaft)
    pscad_params["shaft_D"] = get_D(shaft)
end

function write_parameters!(pscad_params, avr::SEXS)
    pscad_params["avr_Ta_Tb"] = get_Ta_Tb(avr)
    pscad_params["avr_Tb"] = get_Tb(avr)
    pscad_params["avr_K"] = get_K(avr)
    pscad_params["avr_Te"] = get_Te(avr)
    pscad_params["avr_V_min"] = get_V_lim(avr)[1]
    pscad_params["avr_V_max"] = get_V_lim(avr)[2]
end

function write_parameters!(pscad_params, prime_mover::GasTG)
    pscad_params["primemover_R"] = get_R(prime_mover)
    pscad_params["primemover_T1"] = get_T1(prime_mover)
    pscad_params["primemover_T2"] = get_T2(prime_mover)
    pscad_params["primemover_T3"] = get_T3(prime_mover)
    pscad_params["primemover_AT"] = get_AT(prime_mover)
    pscad_params["primemover_Kt"] = get_Kt(prime_mover)
    pscad_params["primemover_V_min"] = get_V_lim(prime_mover)[1]
    pscad_params["primemover_V_max"] = get_V_lim(prime_mover)[2]
    pscad_params["primemover_D_turb"] = get_D_turb(prime_mover)
end

function write_parameters!(pscad_params, prime_mover::HydroTurbineGov)
    pscad_params["primemover_R_perm"] = get_R(prime_mover)  #PSCAD not case-sensitive
    pscad_params["primemover_R_temp"] = get_r(prime_mover)  #PSCAD not case-sensitive
    pscad_params["primemover_Tr"] = get_Tr(prime_mover)
    pscad_params["primemover_Tf"] = get_Tf(prime_mover)
    pscad_params["primemover_Tg"] = get_Tg(prime_mover)
    pscad_params["primemover_VELM"] = get_VELM(prime_mover)
    pscad_params["primemover_gate_position_min"] = get_gate_position_limits(prime_mover).min
    pscad_params["primemover_gate_position_max"] = get_gate_position_limits(prime_mover).max
    pscad_params["primemover_Tw"] = get_Tw(prime_mover)
    pscad_params["primemover_At"] = get_At(prime_mover)
    pscad_params["primemover_D_T"] = get_D_T(prime_mover)
    pscad_params["primemover_q_nl"] = get_q_nl(prime_mover)
end

function write_parameters!(pscad_params, prime_mover::SteamTurbineGov1)
    pscad_params["primemover_R"] = get_R(prime_mover)
    pscad_params["primemover_T1"] = get_T1(prime_mover)
    pscad_params["primemover_valve_position_min"] =
        get_valve_position_limits(prime_mover).min
    pscad_params["primemover_valve_position_max"] =
        get_valve_position_limits(prime_mover).max
    pscad_params["primemover_T2"] = get_T2(prime_mover)
    pscad_params["primemover_T3"] = get_T3(prime_mover)
    pscad_params["primemover_D_T"] = get_D_T(prime_mover)
    pscad_params["primemover_T_rate"] = get_T_rate(prime_mover)
end

function write_parameters!(pscad_params, pss::PSSFixed) end

function write_parameters!(pscad_params, avr::ESAC1A)
    @info "Write function for ESAC1A not implemented"
end

function write_parameters!(pscad_params, tg::TGFixed)
    @info "Write function for TGFixed not implemented"
end

function write_parameters!(pscad_params, avr::AVRFixed)
    @info "Write function for AVRFixed not implemented"
end

function write_parameters(
    psid_component::Transformer2W,
    pscad_component_name,
    pscad_project,
)
    pscad_component = pscad_project.find(pscad_component_name)
    pscad_params = pscad_component.parameters()

    pscad_params["Xl"] = get_x(psid_component)
    if get_r(psid_component) != 0.0
        @error "PSID component has r not equal to 0, but can't set in PSCAD"
    end
    PP.update_parameter_by_dictionary(pscad_component, pscad_params)
end

function write_parameters(
    psid_component::TapTransformer,
    pscad_component_name,
    pscad_project,
)
    @warn "Tap is not set automatically for TapTransformer- confirm manually in PSCAD"
    pscad_component = pscad_project.find(pscad_component_name)
    pscad_params = pscad_component.parameters()

    pscad_params["Xl"] = get_x(psid_component)
    if get_r(psid_component) != 0.0
        @error "PSID component has r not equal to 0, but can't set in PSCAD"
    end

    PP.update_parameter_by_dictionary(pscad_component, pscad_params)
end

function write_parameters(psid_component::Arc, pscad_component_name, pscad_project)
    @info "No parameters written for type Arc"
end

function write_parameters(psid_component::LoadZone, pscad_component_name, pscad_project)
    @info "No parameters written for type LoadZone"
end
function write_parameters(psid_component::Area, pscad_component_name, pscad_project)
    @info "No parameters written for type Area"
end


function write_rating!(pscad_params, static::S, dynamic::DynamicInverter) where {S <: StaticInjection}
    pscad_params["f_base"] = 60.0
    pscad_params["S_base"] = get_base_power(dynamic)
    pscad_params["V_base"] = get_base_voltage(get_bus(static))
end

function write_rating!(pscad_params, static::S, dynamic::DynamicInverter) where {S <: StaticInjection}
    pscad_params["w_base"] = 60.0 * 2 * pi
    pscad_params["I_phase"] =
        get_base_power(dynamic) / get_base_voltage(get_bus(static)) / sqrt(3)
    pscad_params["V_ln"] = get_base_voltage(get_bus(static)) / sqrt(3)
    pscad_params["f_base"] = 60.0
    pscad_params["S_base"] = get_base_power(dynamic)
    pscad_params["V_base"] = get_base_voltage(get_bus(static))
end

function write_parameters(
    psid_component::S,
    pscad_component_name,
    pscad_project,
)  where {S <: StaticInjection}
    pscad_component = nothing
    try
        pscad_component = pscad_project.find(pscad_component_name)
    catch e
        pscad_component = pscad_project.find(pscad_component_name, layer = "enabled_gens")
    end
    pscad_params = pscad_component.parameters()
    psid_dynamic_injector = get_dynamic_injector(psid_component)

    pscad_params["P_out"] = string("P_out_", get_number(get_bus(psid_component)))
    pscad_params["Q_out"] = string("Q_out_", get_number(get_bus(psid_component)))
    pscad_params["f_out"] = string("f_out_", get_number(get_bus(psid_component)))

    write_rating!(pscad_params, psid_component, psid_dynamic_injector)

    PP.update_parameter_by_dictionary(pscad_component, pscad_params)
end

function write_parameters(psid_component::PowerLoad, pscad_component_name, pscad_project)
    pscad_component = pscad_project.find(pscad_component_name)
    pscad_params = pscad_component.parameters()
    pscad_params["PO"] =
        get_base_power(psid_component) * get_active_power(psid_component) / 3 #pscad takes per phase
    pscad_params["QO"] =
        get_base_power(psid_component) * get_reactive_power(psid_component) / 3  #pscad takes per phase
    pscad_params["VBO"] = get_base_voltage(get_bus(psid_component)) / sqrt(3) #pscad takes L-G voltage
    pscad_params["VPU"] = get_magnitude(get_bus(psid_component))
    pscad_params["PQdef"] = "INITIAL_TERMINAL"    #PQ corresponds to initial conditions
    PP.update_parameter_by_dictionary(pscad_component, pscad_params)
end

function write_parameters(psid_component::Line, pscad_component_name, pscad_project) end

function write_parameters(
    psid_component::DynamicBranch,
    pscad_component_name,
    pscad_project,
)
    pscad_component_name = filter(x -> !isspace(x), pscad_component_name)
    pscad_component = pscad_project.find(pscad_component_name)
    @error "IN LINE"
    pscad_params = pscad_component.parameters()
    pscad_params["VR2"] = get_base_voltage(get_from(get_arc(psid_component)))
    pscad_params["len"] = 1e5
    if pscad_component.defn_name[2] == "newpi"
        r = get_r(psid_component)
        if r == 0
            pscad_params["RPUP2"] = 1e-307
        else
            pscad_params["RPUP2"] = r * 1e-5
        end

        x = get_x(psid_component)
        if x == 0
            pscad_params["XLPUP2"] = 1e-307
        else
            pscad_params["XLPUP2"] = x * 1e-5
        end

        b_total = get_b(psid_component)[1] + get_b(psid_component)[2]
        if b_total == 0
            pscad_params["BPUP2"] = 1e-307
        else
            pscad_params["BPUP2"] = b_total * 1e-5
        end
    end
    PP.update_parameter_by_dictionary(pscad_component, pscad_params)
end

function write_ideal_source(
    psid_component::ThermalStandard,
    pscad_component_name,
    pscad_project,
    ramp_time,
)
    pscad_component = pscad_project.find(pscad_component_name)
    pscad_params = pscad_component.parameters()

    pscad_params["Vbase"] = get_base_voltage(get_bus(psid_component))
    pscad_params["Sbase"] = get_base_power(psid_component)
    pscad_params["Vpu"] = get_magnitude(get_bus(psid_component))
    pscad_params["PhT"] = get_angle(get_bus(psid_component)) * (180 / pi)
    pscad_params["Pinit"] = get_active_power(psid_component)
    pscad_params["Qinit"] = get_reactive_power(psid_component)
    pscad_params["Tc"] = ramp_time
    PP.update_parameter_by_dictionary(pscad_component, pscad_params)
end

function write_parameters(psid_component::Source, pscad_component_name, pscad_project)
    pscad_component = nothing
    try
        pscad_component = pscad_project.find(pscad_component_name)
    catch e
        pscad_component = pscad_project.find(pscad_component_name, layer = "enabled_gens")
    end
    pscad_params = pscad_component.parameters()

    pscad_params["V_base"] = get_base_voltage(get_bus(psid_component))
    pscad_params["S_base"] = get_base_power(psid_component)
    pscad_params["V_pf"] = get_magnitude(get_bus(psid_component))
    pscad_params["theta_pf"] = get_angle(get_bus(psid_component)) * (180 / pi)
    #pscad_params["P_out"] = get_active_power(psid_component)
    #pscad_params["Q_out"] = get_reactive_power(psid_component)
    #pscad_params["Spec"]  = 1   #Sets Spec to be "AT_THE_TERMINAL" 

    PP.update_parameter_by_dictionary(pscad_component, pscad_params)
end

function write_parameters(psid_component::Bus, pscad_component_name, pscad_project)
    pscad_component_name = filter(x -> !isspace(x), pscad_component_name)  #PSCAD component can't have name with spaces 
    pscad_component = pscad_project.find(pscad_component_name)
    pscad_params = pscad_component.parameters()

    pscad_params["BaseKV"] = get_base_voltage(psid_component)

    PP.update_parameter_by_dictionary(pscad_component, pscad_params)
end

function write_parameters(
    psid_component::DynamicGenerator,
    pscad_component_name,
    pscad_project,
)
    pscad_component = nothing
    try
        pscad_component = pscad_project.find(pscad_component_name)
    catch e
        pscad_component = pscad_project.find(pscad_component_name, layer = "enabled_gens")
    end
    pscad_params = pscad_component.parameters()
    write_parameters!(pscad_params, psid_component.machine)
    write_parameters!(pscad_params, psid_component.shaft)
    write_parameters!(pscad_params, psid_component.avr)
    write_parameters!(pscad_params, psid_component.prime_mover)
    write_parameters!(pscad_params, psid_component.pss)
    pscad_params["t_GEN"] = "t_GEN"
    pscad_params["t_S2M"] = "t_S2M"
    pscad_params["t_L2N"] = "t_L2N"
    pscad_params["t_RAMP"] = "t_RAMP"

    PP.update_parameter_by_dictionary(pscad_component, pscad_params)
end

function write_parameters(
    psid_component::DynamicInverter,
    pscad_component_name,
    pscad_project,
)
    pscad_component = nothing
    try
        pscad_component = pscad_project.find(pscad_component_name)
    catch e
        pscad_component = pscad_project.find(pscad_component_name, layer = "enabled_gens")
    end
    pscad_params = pscad_component.parameters()

    write_parameters!(pscad_params, psid_component.filter)
    write_parameters!(pscad_params, psid_component.outer_control)
    write_parameters!(pscad_params, psid_component.converter)
    write_parameters!(pscad_params, psid_component.inner_control)
    write_parameters!(pscad_params, psid_component.dc_source)
    write_parameters!(pscad_params, psid_component.freq_estimator)

    pscad_params["t_INV"] = "t_INV"
    pscad_params["t_RAMP"] = "t_RAMP"

    PP.update_parameter_by_dictionary(pscad_component, pscad_params)
end

function write_initial_conditions(
    psid_component::Bus,
    pscad_component_name,
    pscad_project,
    x0_dict,
)
    pscad_component_name = filter(x -> !isspace(x), pscad_component_name)
    pscad_component = pscad_project.find("Bus", pscad_component_name)
    pscad_params = pscad_component.parameters()
    pscad_params["VA"] = get_angle(psid_component)
    pscad_params["VM"] = get_magnitude(psid_component)
    PP.update_parameter_by_dictionary(pscad_component, pscad_params)
end

function write_initial_conditions(
    psid_component::ThermalStandard,
    pscad_component_name,
    pscad_project,
    x0_dict,
)
    pscad_component = nothing
    try
        pscad_component = pscad_project.find(pscad_component_name)
    catch e
        pscad_component = pscad_project.find(pscad_component_name, layer = "enabled_gens")
    end
    pscad_params = pscad_component.parameters()
    pscad_params["V_pf"] = get_magnitude(get_bus(psid_component))
    pscad_params["theta_pf"] = get_angle(get_bus(psid_component))
    PP.update_parameter_by_dictionary(pscad_component, pscad_params)
end

function write_initial_conditions(
    psid_component::DynamicGenerator,
    pscad_component_name,
    pscad_project,
    x0_dict,
)
    pscad_component = nothing
    try
        pscad_component = pscad_project.find(pscad_component_name)
    catch e
        pscad_component = pscad_project.find(pscad_component_name, layer = "enabled_gens")
    end
    pscad_params = pscad_component.parameters()
    for (i, state) in enumerate(get_states(psid_component.machine))
        name = "machine_x0_" * string(i)
        pscad_params[name] = x0_dict[get_name(psid_component)][state]
    end
    for (i, state) in enumerate(get_states(psid_component.shaft))
        name = "shaft_x0_" * string(i)
        pscad_params[name] = x0_dict[get_name(psid_component)][state]
    end
    for (i, state) in enumerate(get_states(psid_component.avr))
        name = "avr_x0_" * string(i)
        pscad_params[name] = x0_dict[get_name(psid_component)][state]
    end
    for (i, state) in enumerate(get_states(psid_component.prime_mover))
        name = "tg_x0_" * string(i)
        pscad_params[name] = x0_dict[get_name(psid_component)][state]
    end
    PP.update_parameter_by_dictionary(pscad_component, pscad_params)
end

function write_initial_conditions(
    psid_component::DynamicInverter,
    pscad_component_name,
    pscad_project,
    x0_dict,
)
    pscad_component = nothing
    try
        pscad_component = pscad_project.find(pscad_component_name)
    catch e
        pscad_component = pscad_project.find(pscad_component_name, layer = "enabled_gens")
    end
    pscad_params = pscad_component.parameters()
    for (i, state) in enumerate(get_states(psid_component.filter))
        name = "filter_x0_" * string(i)
        pscad_params[name] = x0_dict[get_name(psid_component)][state]
    end
    for (i, state) in enumerate(get_states(psid_component.outer_control))
        name = "outercontrol_x0_" * string(i)
        pscad_params[name] = x0_dict[get_name(psid_component)][state]
    end
    for (i, state) in enumerate(get_states(psid_component.converter))
        name = "converter_x0_" * string(i)
        pscad_params[name] = x0_dict[get_name(psid_component)][state]
    end
    for (i, state) in enumerate(get_states(psid_component.inner_control))
        name = "innercontrol_x0_" * string(i)
        pscad_params[name] = x0_dict[get_name(psid_component)][state]
    end
    for (i, state) in enumerate(get_states(psid_component.dc_source))
        name = "dcsource_x0_" * string(i)
        pscad_params[name] = x0_dict[get_name(psid_component)][state]
    end
    for (i, state) in enumerate(get_states(psid_component.freq_estimator))
        name = "freqestimator_x0_" * string(i)
        pscad_params[name] = x0_dict[get_name(psid_component)][state]
    end
    PP.update_parameter_by_dictionary(pscad_component, pscad_params)
end

function write_setpoints(
    psid_component::DynamicInjection,
    pscad_component_name::String,
    pscad_project,
    setpoints_dict,
)
    pscad_component = nothing
    try
        pscad_component = pscad_project.find(pscad_component_name)
    catch e
        pscad_component = pscad_project.find(pscad_component_name, layer = "enabled_gens")
    end
    pscad_params = pscad_component.parameters()

    pscad_params["V_ref"] = setpoints_dict[get_name(psid_component)]["V_ref"]
    pscad_params["Q_ref"] = setpoints_dict[get_name(psid_component)]["Q_ref"]
    pscad_params["P_ref"] = setpoints_dict[get_name(psid_component)]["P_ref"]
    pscad_params["omega_ref"] = setpoints_dict[get_name(psid_component)]["ω_ref"]
    PP.update_parameter_by_dictionary(pscad_component, pscad_params)
end

function label_breakers_sequential(pscad_project)
    breakers = pscad_project.find_all("master:breaker3")
    for (i, pscad_component) in enumerate(breakers)
        pscad_params = pscad_component.parameters()
        pscad_params["NAME"] = string("BRK_", i)
        PP.update_parameter_by_dictionary(pscad_component, pscad_params)
    end
end
