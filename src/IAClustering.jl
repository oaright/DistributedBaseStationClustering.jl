##########################################################################
# IAClustering
#
# Evaluation environment for the IAClustering project
# https://gitr.sys.kth.se/rabr5411/IAClustering.jl
##########################################################################

module IAClustering

using CoordinatedPrecoding
import Lumberjack

export
    # assignment
    Chen2014_LinearObjClustering_Exhaustive, ExhaustiveSearchClustering,
    GrandCoalitionClustering, RandomClustering,

    # precoding
    RobustChen2014_MaxSINR, NaiveChen2014_MaxSINR,
    RobustIntraclusterWMMSE, NaiveIntraclusterWMMSE

include("assignment/assignment.jl")
include("assignment/Chen2014_LinearObjClustering_Exhaustive.jl")
include("assignment/ExhaustiveSearchClustering.jl")
include("assignment/GrandCoalitionClustering.jl")
include("assignment/RandomClustering.jl")

include("precoding/Chen2014_MaxSINR.jl")
include("precoding/IntraclusterWMMSE.jl")

include("feasibility.jl")
include("partitions.jl")

##########################################################################
# Logging defaults
let
    console = Lumberjack._lumber_mill.timber_trucks["console"]
    Lumberjack.configure(console; mode = "warn")
    file = Lumberjack.add_truck(Lumberjack.LumberjackTruck("default.log", "info"), "default")
end

end