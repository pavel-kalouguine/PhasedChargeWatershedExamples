# Command-line launcher for the interactive density viewer.
#
#   julia viewer.jl path/to/data.json
#   julia viewer.jl path/to/results.jld2
#
# What is drawn follows from the file that is given. A .json holds phased data only, so
# the density alone is shown; a .jld2 written by prewatershed.jl holds a watershed result
# as well, and the boundaries between the basins are drawn as white lines over the
# density, and a separate window postprocesses them for every view at once. A result
# carries the phased data it was computed from, so the density and the basins on screen
# always belong together.
#
# Opens one view. The "Add a view" button clones the current settings into a new window.
# Views can be closed independently; the program ends with the last of them, or with the
# window holding the basin controls.
using Pkg
Pkg.activate(@__DIR__)  # Ensure project environment is active

using GLMakie
using PhasedChargeWatershed

# What to show, and on which colour scale, according to what the file holds
function load_input(path)
    extension = lowercase(splitext(path)[2])
    if extension == ".json"
        pd = load_data(path)
        return pd, nothing, global_density_limits(pd)
    elseif extension == ".jld2"
        watershed = load_result(path)
        return watershed.phased_data, Observable(watershed), global_density_limits(watershed)
    end
    error("do not know what to do with \"$extension\": " *
          "expected .json (phased data) or .jld2 (watershed results)")
end

function main(args)
    length(args) == 1 || error("usage: julia viewer.jl <data.json | results.jld2>")
    input_path = args[1]
    isfile(input_path) || error("input file not found: $input_path")
    pd, result, climits = load_input(input_path)

    # The set of open views; the program runs until the last one is closed
    screens = Set{GLMakie.Screen}()

    function add_view(init = nothing)
        fig = build_viewer(pd; on_add_view = add_view, init = init, colorrange = climits,
                           result = result)
        screen = GLMakie.Screen()
        display(screen, fig)                 # open a new window
        push!(screens, screen)
        on(events(fig.scene).window_open) do isopen
            isopen || delete!(screens, screen)   # drop it once the window closes
        end
        return
    end

    controls = nothing
    controls_open = Observable(true)
    if result !== nothing
        fig = build_basin_controls(result)
        controls = GLMakie.Screen()
        display(controls, fig)
        on(isopen -> controls_open[] = isopen, events(fig.scene).window_open)
    end

    add_view()
    # the program ends with the last view, or with the basin controls
    while !isempty(screens) && controls_open[]
        sleep(0.1)
    end

    # Create a shallow copy of the set to avoid modifying it while iterating
    screens_copy = Set(screens)
    foreach(close, screens_copy)
    controls === nothing || close(controls)
end

main(ARGS)
