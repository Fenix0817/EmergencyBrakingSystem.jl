


function evaluate_scenario(ego_v, ped_v, ped_theta, obstacles, hitpoint, ped_right_side)

    timestep = 0.05

    params = CrosswalkParams()    
    if (length(obstacles) > 0)
        params.obstacles = obstacles
        params.obstacles_visible = true
    else
        params.obstacles_visible = false
    end
    params.roadway_length = 400.0

    env = CrosswalkEnv(params);


    # fix values
    ped_x = 50.0
    ego_y = 0
    ped_t_collision = 3.0

    ped_y_offset_hitpoint = VehicleDef().width * hitpoint / 100 - VehicleDef().width/2
    ped_y_end = ped_y_offset_hitpoint
    if (ped_right_side)
        ped_y_start = ped_y_end - ped_t_collision * ped_v
    else
        ped_y_start = ped_y_end + ped_t_collision * ped_v
    end
    ego_x = ped_x - ego_v * ped_t_collision - VehicleDef().length/2;

    ego_id = 1
    ped_id = 2
    ped2_id = 3
    ped3_id = 4

    # Car definition
    ego_initial_state = VehicleState(VecSE2(ego_x, ego_y, 0.), env.roadway.segments[1].lanes[1], env.roadway, ego_v)
    ego = Vehicle(ego_initial_state, VehicleDef(), ego_id)

    # Pedestrian definition using our new Vehicle definition
    ped_initial_state = VehicleState(VecSE2(ped_x,ped_y_start,ped_theta), env.crosswalk, env.roadway, ped_v)
    ped = Vehicle(ped_initial_state, AutomotivePOMDPs.PEDESTRIAN_DEF, ped_id)

    ped2 = Vehicle(VehicleState(VecSE2(40., 3., -1.57), env.crosswalk, env.roadway, 0.), AutomotivePOMDPs.PEDESTRIAN_DEF, ped2_id)
    ped3 = Vehicle(VehicleState(VecSE2(53., 10., -1.57), env.crosswalk, env.roadway, 1.), AutomotivePOMDPs.PEDESTRIAN_DEF, ped3_id)

    scene = Scene()
    push!(scene, ego)
    push!(scene, ped)
    push!(scene, ped2)
    push!(scene, ped3)

    pos_noise = 0.0
    vel_noise = 0.0
    false_positive_rate = 0.0
    false_negative_rate = 0.0
    rng = MersenneTwister(1);
    sensor = AutomotiveSensors.GaussianSensor(AutomotiveSensors.LinearNoise(10, pos_noise, 0.0), 
                     AutomotiveSensors.LinearNoise(10, vel_noise, 0.0), false_positive_rate, false_negative_rate, rng) 

    # define a model for each entities present in the scene
    models = Dict{Int, DriverModel}()

    models[ego_id] = EmergencyBrakingSystem.EmergencySystem(a=LatLonAccel(0.0, 0.0),
        env=env,
        sensor=sensor, 
        obstacles=env.obstacles, 
        SAFETY_DISTANCE_LON=1.0,
        AX_MAX=-10.0,
        THRESHOLD_COLLISION_RATE = 0.6,
        THRESHOLD_TIME_TO_REACT = 0.99,    
        timestep=timestep)

    models[ped_id] = ConstantPedestrian(v_desired=ped_v, dawdling_amp=0.0) # dumb model
    models[ped2_id] = ConstantPedestrian(v_desired=0.0, dawdling_amp=0.05) # dumb model
    models[ped3_id] = ConstantPedestrian(v_desired=1.0, dawdling_amp=0.05) # dumb model

    nticks = 80
    rec = SceneRecord(nticks+1, timestep)

    risk = Float64[]
    collision_rate = Float64[]
    ttc = Float64[]
    brake_request = Bool[]
    prediction = Vector{Array{Float64}}()
    collision = Bool[]
    sensor_observations = [Vehicle[]]
    ego_vehicle = Vehicle[]

    obs_callback = (EmergencyBrakingSystem.ObservationCallback(ego_vehicle, risk, collision_rate, ttc, brake_request, prediction, sensor_observations, collision),)

    simulate!(rec, scene, env.roadway, models, nticks, obs_callback)

    return (rec, timestep, env, ego_vehicle, sensor, sensor_observations, risk, ttc, collision_rate, brake_request, prediction, collision)

end