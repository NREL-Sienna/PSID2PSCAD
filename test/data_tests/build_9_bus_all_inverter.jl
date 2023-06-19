using PowerSystems
using PowerFlows
const PSY = PowerSystems

function build_computation_benchmarks(; kwargs...)

    tg_type1() = PSY.TGTypeI(
        0.02, #R
        0.1, #Ts
        0.45, #Tc
        0.0, #T3
        0.0, #T4
        50.0, #T5
        (min = 0.3, max = 1.2), #P_lims
    )

    pss_none() = PSY.PSSFixed(0.0)

    pll() = PSY.KauraPLL(
        ω_lp = 500.0, #Cut-off frequency for LowPass filter of PLL filter.
        kp_pll = 0.84,  #PLL proportional gain
        ki_pll = 4.69,   #PLL integral gain
    )

    avr_type1() = PSY.AVRTypeI(
        20.0, #Ka - Gain
        1.0, #Ke
        0.001, #Kf
        0.02, #Ta
        0.7, #Te
        1, #Tf
        0.001, #Tr
        (min = -5.0, max = 5.0),
        0.0006, #Ae - 1st ceiling coefficient
        0.9,
    ) #Be - 2nd ceiling coefficient

    heterogeneous_saft(H, D) = PSY.SingleMass(H,D)

    machine_anderson() = PSY.AndersonFouadMachine(
        0.0, #R
        0.8979, #Xd
        0.646, #Xq
        0.2995, #Xd_p
        0.646, #Xq_p
        0.23, #Xd_pp
        0.4, #Xq_pp
        3.0, #Td0_p
        0.1, #Tq0_p
        0.01, #Td0_pp
        0.033, #Tq0_pp
    )

    ######## Filter ######
    filt() = PSY.LCLFilter(lf = 0.08, rf = 0.003, cf = 0.074, lg = 0.2, rg = 0.01)

    ######## Inner Control ######
    inner_control() = PSY.VoltageModeControl(
        kpv = 0.59,     #Voltage controller proportional gain
        kiv = 736.0,    #Voltage controller integral gain
        kffv = 0.0,     #Binary variable enabling the voltage feed-forward in output of current controllers
        rv = 0.0,       #Virtual resistance in pu
        lv = 0.2,       #Virtual inductance in pu
        kpc = 1.27,     #Current controller proportional gain
        kic = 14.3,     #Current controller integral gain
        kffi = 0.0,     #Binary variable enabling the current feed-forward in output of current controllers
        ωad = 50.0,     #Active damping low pass filter cut-off frequency
        kad = 0.2,
    )

    current_mode_inner() = PSY.CurrentModeControl(
    kpc = 0.37,     #Current controller proportional gain
    kic = 0.7,     #Current controller integral gain
    kffv = 0,#1.0,     #Binary variable enabling the voltage feed-forward in output of current controllers
    )

    function outer_control_droop()
        function active_droop()
            return PSY.ActivePowerDroop(Rp = 0.05, ωz = 2 * pi * 5)
        end
        function reactive_droop()
            return PSY.ReactivePowerDroop(kq = 0.01, ωf = 2 * pi * 5)
        end
        return OuterControl(active_droop(), reactive_droop())
    end

    function outer_control_gfoll()
        function active_pi()
            return PSY.ActivePowerPI(Kp_p = 2.0, Ki_p = 30.0, ωz = 0.132 * 2 * pi * 50)
        end
        function reactive_pi()
            return PSY.ReactivePowerPI(Kp_q = 2.0, Ki_q = 30.0, ωf = 0.132 * 2 * pi * 50)
        end
        return OuterControl(active_pi(), reactive_pi())
    end

    function outer_control_vsm()
        virtual_H = VirtualInertia(
            2.0, #Ta:: VSM inertia constant
            400.0, #kd:: VSM damping coefficient
            20.0, #kω:: Frequency droop gain in pu
            2 * pi * 50.0,
        ) #ωb:: Rated angular frequency

        Q_control = PSY.ReactivePowerDroop(
            0.2, #kq:: Reactive power droop gain in pu
            1000.0,
        ) #ωf:: Reactive power cut-off low pass filter frequency

        return OuterControl(virtual_H, Q_control)
    end


    function add_grid_forming(storage, capacity, vsm = false)
        if vsm
            oc = outer_control_vsm()
            fe = pll()
        else
            oc = outer_control_droop()
            fe = PSY.FixedFrequency()
        end

        return DynamicInverter(
            name = storage.name,
            ω_ref = 1.0, # ω_ref,
            converter = PSY.AverageConverter(rated_voltage = 138.0, rated_current = (capacity*1e3)/138.0), #converter
            outer_control = oc,
            inner_control = inner_control(), #inner control voltage source
            dc_source = PSY.FixedDCSource(voltage = 600.0), #dc source
            freq_estimator = fe, #pll 
            filter = filt(), #filter
        )
    end

    function add_grid_following(storage, capacity)
        return DynamicInverter(
            name = storage.name,
            ω_ref = 1.0, # ω_ref,
            converter = AverageConverter(rated_voltage = 138.0, rated_current = (capacity*1e3)/138.0), #converter
            outer_control = outer_control_gfoll(), #ogetuter control
            inner_control = current_mode_inner(), #inner control voltage source
            dc_source = FixedDCSource(voltage = 600.0), #dc source
            freq_estimator = pll(), #pll
            filter = filt(), #filter
        )
    end

    function add_battery(sys, battery_name, bus_name, capacity, P, Q)
        return GenericBattery(
            name = battery_name,
            bus = get_component(Bus, sys, bus_name),
            available = true,
            prime_mover = PrimeMovers.BA,
            active_power = P,
            reactive_power = Q,
            rating = 1.1,
            base_power = capacity,
            initial_energy = 50.0,
            state_of_charge_limits = (min = 5.0, max = 100.0),
            input_active_power_limits = (min = 0.0, max = 10.0),
            output_active_power_limits = (min = 0.0, max = 10.0),
            reactive_power_limits = (min = -1.0, max = 1.0),
            efficiency = (in = 0.80, out = 0.90),
        )
    end

    function dyn_gen_second_order(generator, H, D)
        return DynamicGenerator(
            name = generator.name,
            ω_ref = 1.0, # ω_ref,
            machine = machine_anderson(), #machine
            shaft = heterogeneous_saft(H, D), #shaft
            avr = avr_type1(), #avr
            prime_mover = tg_type1(), #tg
            pss = pss_none(), #pss
        )
    end

    sys_size=get(kwargs, :system_size, 9)
    GF=get(kwargs, :grid_forming, 0.05)
    Gf=get(kwargs, :grid_following, 0.15)
    trip_gen=get(kwargs, :trip_percent, 0.04)
    trip_gen_active=get(kwargs, :trip_Active_pug, 0.7)

    file_path = joinpath(@__DIR__,  "9_bus.raw")
    sys = PSY.System(file_path)
    @assert length(PSY.get_components(Bus, sys)) == sys_size

    set_units_base_system!(sys, "DEVICE_BASE")

    df = run_powerflow(sys)
    total_power=sum(df["bus_results"].P_gen)

    syncGen = collect(get_components(Generator, sys));
    trip_cap=total_power*trip_gen/trip_gen_active
    for g in syncGen
        if g.bus.number == 3
            set_base_power!(g, trip_cap)
        end
        if get_base_power(g) == 500.000
            set_base_power!(g, 200.00)
        elseif get_base_power(g) == 250.000
            set_base_power!(g, 175.00)
        end
    end

    bus_capacity = Dict()
    for g in syncGen
        bus_capacity[g.bus.name] = get_base_power(g)*1.2
    end

    total_capacity=sum(values(bus_capacity))

    for gen in syncGen
        remove_component!(sys, gen)
    end

    for g in syncGen
        if g.bus.number == 1
            continue
        end
        if g.bus.number < 4
            storage=add_battery(sys, join(["GF_Battery-", g.bus.number]), g.bus.name, GF*bus_capacity[g.bus.name]*2, get_active_power(g), get_reactive_power(g))
            add_component!(sys, storage)
            inverter=add_grid_forming(storage, GF*bus_capacity[g.bus.name]*2)
            add_component!(sys, inverter, storage)
        else
            storage=add_battery(sys, join(["Gf_Battery-", g.bus.number]), g.bus.name, Gf*bus_capacity[g.bus.name]*2, get_active_power(g), get_reactive_power(g))
            add_component!(sys, storage)
            inverter=add_grid_following(storage, Gf*bus_capacity[g.bus.name]*2)
            add_component!(sys, inverter, storage)
        end
    end

    storage=add_battery(sys, join(["GF_Battery-", 1]), "Bus_1", GF*bus_capacity["Bus_1"]*10, 1.0, 0.0)
    add_component!(sys, storage)
    inverter=add_grid_forming(storage, GF*bus_capacity["Bus_1"]*10, true)
    add_component!(sys, inverter, storage)

    run_powerflow!(sys)
    return sys
end

sys = build_computation_benchmarks()

using PowerSimulationsDynamics
using Sundials

sim = Simulation(
        ResidualModel,
        sys,
        pwd(),
        (0.0, 10.0),
        all_lines_dynamic = true,
    )

# Run Perturbation
execute!(sim, IDA(); abstol = 1e-9, reltol = 1e-9)

to_json(sys, joinpath(@__DIR__, "..", "systems_tests", "9_bus_all_inverter.json"), force =true )
