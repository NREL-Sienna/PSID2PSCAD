
bus_length_const = 6

function build_system(sys::System, project, coorDict; add_gen_breakers = false, add_load_breakers = false, add_line_breakers = false, add_multimeters = false)
    main = project.user_canvas("Main")
    y_coord = 2
    for signal in ["t_INV", "t_GEN", "t_L2N", "t_S2M", "t_RAMP"]
        t_INV_const = main.add_component("master", "const", 3, y_coord)
        t_INV_const.set_parameters((Name = signal))
        t_INV = main.add_component("master", "datalabel", 5, y_coord)
        t_INV.set_parameters(Name = signal)
        y_coord += 3 
    end 
    components = collect(get_components(Component, sys))
    for c in components
        @info "building component: $(get_name(c)) of type $(typeof(c))"
        build_component(c, get_name(c), main, coorDict, sys; add_gen_breakers, add_load_breakers, add_line_breakers, add_multimeters)
    end 
end

function build_component(psid_component::Bus, pscad_component_name, pscad_canvas, coorDict, sys; add_gen_breakers = false, add_load_breakers = false, add_line_breakers = false, add_multimeters = false)
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
            multimeter_offset_x = 1
            multimeter_offset_y = 6 
        else    
            multimeter_offset_x = 7
            multimeter_offset_y = 0 
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
            RMS = 2,    # 2 -> digital measurement 
            MeasPh = 1, # 1 -> measure in radians 
            Vrms = "v_"*pscad_component_name,
            Ph = "ph_"*pscad_component_name,
            Freq = 30000.0, #frequency for digital measurement 
            BaseV = get_base_voltage(psid_component)
            )
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
    add_gen_breakers = false,
    add_load_breakers = false,
    add_line_breakers = false,
    add_multimeters = false
)
    static_injector = get_component(StaticInjection, sys, pscad_component_name)
    Busname = get_name(get_bus(static_injector))
    if coorDict[Busname].devices_location == "s"
        mach_coors = (coorDict[Busname].centerpoint[1] - 16, coorDict[Busname].centerpoint[2] + 7)
        new_mach = pscad_canvas.add_component(
            "PSID_Library_Inverters",
            "SAUERPAI_SEXS_TGOV1_PSSFIXED",
            mach_coors[1],
            mach_coors[2],
        )
    elseif coorDict[Busname].devices_location == "n"
        mach_coors = (coorDict[Busname].centerpoint[1] - 16, coorDict[Busname].centerpoint[2] - 7)
        new_mach = pscad_canvas.add_component(
            "PSID_Library_Inverters",
            "SAUERPAI_SEXS_TGOV1_PSSFIXED",
            mach_coors[1],
            mach_coors[2],
        )
    elseif coorDict[Busname].devices_location == "e"
        mach_coors = (coorDict[Busname].centerpoint[1] + 7, coorDict[Busname].centerpoint[2] + 10)
        new_mach = pscad_canvas.add_component(
            "PSID_Library_Inverters",
            "SAUERPAI_SEXS_TGOV1_PSSFIXED",
            mach_coors[1],
            mach_coors[2],
        )
    elseif coorDict[Busname].devices_location == "w"
        mach_coors = (coorDict[Busname].centerpoint[1] - 13, coorDict[Busname].centerpoint[2] + 10)
        new_mach = pscad_canvas.add_component(
            "PSID_Library_Inverters",
            "SAUERPAI_SEXS_TGOV1_PSSFIXED",
            mach_coors[1],
            mach_coors[2],
        )
    else
        @error "No direction specified for component placement"
        println(Busname)
    end
    new_mach.set_parameters(Name = pscad_component_name)
    if add_gen_breakers == true
        gen_br_offset = 8
        gen_br_coors = (mach_coors[1] + gen_br_offset, mach_coors[2])
        gen_br = pscad_canvas.add_component(
            "master",
            "breaker3",
            gen_br_coors[1],
            gen_br_coors[2]
            )
        br_name =  "br_"*replace(pscad_component_name, "-" => "_")*"_1"
        gen_br.set_parameters(NAME = br_name)        #TODO - should give these meaningful names based on :from and :to in PSID
        _add_breaker_logic_peripherals(pscad_canvas, br_name, gen_br_coors)
        new_wire =
            pscad_canvas.create_wire(gen_br.get_port_location("N1"), coorDict[Busname].centerpoint)
    else
        new_wire =
            pscad_canvas.create_wire(new_mach.get_port_location("POI"), coorDict[Busname].centerpoint)
    end
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
    add_gen_breakers = false,
    add_load_breakers = false,
    add_line_breakers = false, 
    add_multimeters = false
)
    static_injector = get_component(StaticInjection, sys, pscad_component_name)
    Busname = get_name(get_bus(static_injector))
    if coorDict[Busname].devices_location == "s"
        inv_coors = (coorDict[Busname].centerpoint[1] - 3, coorDict[Busname].centerpoint[2] + 7)
        new_inv = pscad_canvas.add_component(
            "PSID_Library_Inverters",
            "DROOP_GFM",
            inv_coors[1],
            inv_coors[2]
        )
    elseif coorDict[Busname].devices_location == "n"
        inv_coors = (coorDict[Busname].centerpoint[1] - 3, coorDict[Busname].centerpoint[2] - 7)
        new_inv = pscad_canvas.add_component(
            "PSID_Library_Inverters",
            "DROOP_GFM",
            inv_coors[1],
            inv_coors[2]
        )
    elseif coorDict[Busname].devices_location == "e"
        inv_coors = (coorDict[Busname].centerpoint[1] + 7, coorDict[Busname].centerpoint[2] + 5)
        new_inv = pscad_canvas.add_component(
            "PSID_Library_Inverters",
            "DROOP_GFM",
            inv_coors[1],
            inv_coors[2]
        )
    elseif coorDict[Busname].devices_location == "w"
        inv_coors = (coorDict[Busname].centerpoint[1] - 13, coorDict[Busname].centerpoint[2] + 5)
        new_inv = pscad_canvas.add_component(
            "PSID_Library_Inverters",
            "DROOP_GFM",
            inv_coors[1],
            inv_coors[2]
        )
    else
        @error "No direction specified for component placement"
        println(Busname)
    end
    new_inv.set_parameters(Name = pscad_component_name)
    if add_gen_breakers == true
        inv_br_offset = 8
        inv_br_coors = (inv_coors[1] + inv_br_offset, inv_coors[2])
        inv_br = pscad_canvas.add_component(
            "master",
            "breaker3",
            inv_br_coors[1],
            inv_br_coors[2]
            )
        br_name =  "br_"*replace(pscad_component_name, "-" => "_")*"_1"
        inv_br.set_parameters(NAME = br_name)        #TODO - should give these meaningful names based on :from and :to in PSID
        _add_breaker_logic_peripherals(pscad_canvas, br_name, inv_br_coors)
        new_wire =
            pscad_canvas.create_wire(inv_br.get_port_location("N1"), coorDict[Busname].centerpoint)
    else
        new_wire =
        pscad_canvas.create_wire(new_inv.get_port_location("POI"), coorDict[Busname].centerpoint)
    end
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
    add_gen_breakers = false,
    add_load_breakers = false,
    add_line_breakers = false, 
    add_multimeters = false
)
    static_injector = get_component(StaticInjection, sys, pscad_component_name)
    Busname = get_name(get_bus(static_injector))
    if coorDict[Busname].devices_location == "s"
        inv_coors = (coorDict[Busname].centerpoint[1] + 10, coorDict[Busname].centerpoint[2] + 7)
        new_inv = pscad_canvas.add_component(
            "PSID_Library_Inverters",
            "GFL_KAURA_PLL",
            inv_coors[1],
            inv_coors[2]
        )
    elseif coorDict[Busname].devices_location == "n"
        inv_coors = (coorDict[Busname].centerpoint[1] + 10, coorDict[Busname].centerpoint[2] - 7)
        new_inv = pscad_canvas.add_component(
            "PSID_Library_Inverters",
            "GFL_KAURA_PLL",
            inv_coors[1],
            inv_coors[2]
        )
    elseif coorDict[Busname].devices_location == "e"
        inv_coors = (coorDict[Busname].centerpoint[1] + 7, coorDict[Busname].centerpoint[2])
        new_inv = pscad_canvas.add_component(
            "PSID_Library_Inverters",
            "GFL_KAURA_PLL",
            inv_coors[1],
            inv_coors[2]
        )
    elseif coorDict[Busname].devices_location == "w"
        inv_coors = (coorDict[Busname].centerpoint[1] - 13, coorDict[Busname].centerpoint[2])
        new_inv = pscad_canvas.add_component(
            "PSID_Library_Inverters",
            "GFL_KAURA_PLL",
            inv_coors[1],
            inv_coors[2]
        )
    else
        @error "No direction specified for component placement"
        println(Busname)
    end
    new_inv.set_parameters(Name = pscad_component_name)
    if add_gen_breakers == true
        inv_br_offset = 8
        inv_br_coors = (inv_coors[1] + inv_br_offset, inv_coors[2])
        inv_br = pscad_canvas.add_component(
            "master",
            "breaker3",
            inv_br_coors[1],
            inv_br_coors[2]
            )
        br_name =  "br_"*replace(pscad_component_name, "-" => "_")*"_1"
        inv_br.set_parameters(NAME = br_name)        #TODO - should give these meaningful names based on :from and :to in PSID
        _add_breaker_logic_peripherals(pscad_canvas, br_name, inv_br_coors)
        new_wire =
            pscad_canvas.create_wire(inv_br.get_port_location("N1"), coorDict[Busname].centerpoint)
    else
        new_wire =
        pscad_canvas.create_wire(new_inv.get_port_location("POI"), coorDict[Busname].centerpoint)
    end
end

function build_component(psid_component::Line, pscad_component_name, pscad_canvas, coorDict, sys; add_gen_breakers = false, add_load_breakers = false, add_line_breakers = false, add_multimeters = false)
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
        br1_name =  "br_"*replace(pscad_component_name, "-" => "_")*"_1"
        br2_name =  "br_"*replace(pscad_component_name, "-" => "_")*"_2"
        new_br1.set_parameters(NAME = br1_name)        #TODO - should give these meaningful names based on :from and :to in PSID
        new_br2.set_parameters(NAME = br2_name)
        _add_breaker_logic_peripherals(pscad_canvas, br1_name, br_coors1)
        _add_breaker_logic_peripherals(pscad_canvas, br2_name, br_coors2)
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

function _add_breaker_logic_peripherals(pscad_canvas, br_name, br_coord)
    brk_logic = pscad_canvas.add_component("PSID_Library", "simple_brk_logic", br_coord[1], br_coord[2] + 3)
    brk_logic.set_parameters(Name = br_name)
    brk_logic.set_parameters(t_break = 0.0)
    label = pscad_canvas.add_component("master", "datalabel", br_coord[1], br_coord[2] + 1)
    label.set_parameters(Name = br_name)
end 

function build_component(
    psid_component::Transformer2W,
    pscad_component_name,
    pscad_canvas,
    coorDict,
    sys; 
    add_gen_breakers= false,
    add_load_breakers = false,
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
    add_gen_breakers = false,
    add_load_breakers = false,
    add_line_breakers = false, 
    add_multimeters = false
)
    loadbus = get_name(get_bus(psid_component))
    load_coors = (coorDict[loadbus].centerpoint[1] + 4, coorDict[loadbus].centerpoint[2] + 2)
    new_load = pscad_canvas.add_component(
        "master",
        "fixed_load",
        load_coors[1],
        load_coors[2]
    )
    new_load.set_parameters(Name = pscad_component_name)
    if add_load_breakers == true
        br_coors = (load_coors[1]-2, load_coors[2]-1) 
        new_br = pscad_canvas.add_component(
            "master",
            "breaker3",
            br_coors[1],
            br_coors[2]
            )
        br_name =  "br_"*replace(pscad_component_name, "-" => "_")*"_1"
        new_br.set_parameters(NAME = br_name)        #TODO - should give these meaningful names based on :from and :to in PSID
        _add_breaker_logic_peripherals(pscad_canvas, br_name, br_coors)
        new_wire = pscad_canvas.add_wire(new_br.get_port_location("N2"), coorDict[loadbus].centerpoint)
    else
    new_wire = pscad_canvas.create_wire(new_load.get_port_location("IA"), coorDict[loadbus].centerpoint)
    end
end

function build_component(psid_component::Arc, pscad_component_name, pscad_canvas, coorDict, sys; add_gen_breakers = false, add_load_breakers = false, add_line_breakers = false, add_multimeters = false)
    @info "Skipping build for type Arc"
end

function build_component(
    psid_component::LoadZone,
    pscad_component_name,
    pscad_canvas,
    coorDict,
    sys; 
    add_gen_breakers = false,
    add_load_breakers = false,
    add_line_breakers = false, 
    add_multimeters = false
)
    @info "Skipping build for type LoadZone"
end

function build_component(psid_component::Area, pscad_component_name, pscad_canvas, coorDict, sys; add_gen_breakers = false, add_load_breakers = false, add_line_breakers = false, add_multimeters = false)
    @info "Skipping build for type Area"
end

function build_component(
    psid_component::GenericBattery,
    pscad_component_name,
    pscad_canvas,
    coorDict,
    sys; 
    add_gen_breakers = false,
    add_load_breakers = false,
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
    add_gen_breakers = false,
    add_load_breakers = false,
    add_line_breakers = false, 
    add_multimeters = false
)
    @info "Skipping build for type ThermalStandard"
end