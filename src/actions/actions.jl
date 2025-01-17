module Actions
    import ..Wilsonloops:Wilson_loop_set,make_staples,Wilson_loop_set,
            make_cloverloops,Tensor_derivative_set, make_loops
    import ..SUN_generator:Generator
    import ..Rhmc:RHMC


    abstract type GaugeActionParam end

    abstract type FermiActionParam end

    abstract type SmearingParam end

    struct SmearingParam_nosmearing <: SmearingParam 
    end

    abstract type SmearingParam_single <: SmearingParam
    end

    abstract type SmearingParam_multi <: SmearingParam
    end

    mutable struct SmearingParam_stout <: SmearingParam_single
        staples_for_stout::Array{Array{Wilson_loop_set,1},1}
        tensor_derivative::Array{Tensor_derivative_set,1}
        staples_for_stout_dag::Array{Array{Wilson_loop_set,1},1}
        tensor_derivative_dag::Array{Tensor_derivative_set,1}
        ρs::Array{Float64,1}
        #ρs::Array{Float64,1}
    end

    mutable struct SmearingParam_stout_multi <: SmearingParam_multi
        staples_for_stout::Array{Array{Wilson_loop_set,1},1}
        tensor_derivative::Array{Tensor_derivative_set,1}
        staples_for_stout_dag::Array{Array{Wilson_loop_set,1},1}
        tensor_derivative_dag::Array{Tensor_derivative_set,1}
        ρs::Array{Array{Float64,1},1}
        #ρs::Array{Float64,1}
    end

    const Nosmearing = SmearingParam_nosmearing
    const Stout = SmearingParam_stout

    mutable struct GaugeActionParam_standard <: GaugeActionParam
        β::Float64
        NTRACE::Int64
    end

    
    mutable struct GaugeActionParam_autogenerator <: GaugeActionParam
        βs::Array{Float64,1}
        β::Float64
        numactions::Int64
        NTRACE::Int64
        loops::Array{Wilson_loop_set,1}
        staples::Array{Array{Wilson_loop_set,1},1}
        couplinglist::Array{String,1}
    end

    





    """
    ```Setup_Gauge_action(β;actiontype="standard")````
    - β: Coupling value

    Set up the information about the Gauge action.
    You can set the coupling value β.

    Now only SU(3) case is supported.
    """
    function Setup_Gauge_action(β;actiontype="standard")
        if actiontype == "standard"
            NTRACE =3
            return GaugeActionParam_standard(β,NTRACE)
        end
    end

    Base.@kwdef struct FermiActionParam_Wilson <: FermiActionParam
        hop::Float64  = 0.141139#Hopping parameter
        r::Float64  = 1#Wilson term
        #eps::Float64 = 1e-8
        eps::Float64 = 1e-19
        Dirac_operator::String = "Wilson"
        MaxCGstep::Int64 = 3000 
        quench::Bool = false
        smearing::SmearingParam 

        function FermiActionParam_Wilson(hop,r,eps,Dirac_operator,MaxCGstep,quench
            ;smearingparameters = "nothing",
            loops_list = nothing,
            coefficients  = nothing,
            numlayers = 1,
            L = nothing)

            smearing = construct_smearing(smearingparameters,loops_list,L,coefficients,numlayers)
            #smearing = Nosmearing()
            #if smearingparameters == nothing
            #    smearing = Nosmearing()
            #end
            return new(hop,r,eps,Dirac_operator,MaxCGstep,quench,smearing)
        end

    end

    const Clover_coefficient  = 1.5612

    Base.@kwdef struct FermiActionParam_WilsonClover <: FermiActionParam
        hop::Float64  = 0.141139#Hopping parameter
        r::Float64  = 1#Wilson term
        #eps::Float64 = 1e-8
        eps::Float64 = 1e-19
        Dirac_operator::String = "WilsonClover"
        MaxCGstep::Int64 = 3000 
        Clover_coefficient::Float64 = Clover_coefficient 
        #CloverFμν::Array{ComplexF64,4}
        internal_flags::Array{Bool,1}
        inn_table::Array{Int64,3}
        _ftmp_vectors::Array{Array{ComplexF64,3},1}
        _is1::Array{Int64,1}
        _is2::Array{Int64,1}
        quench::Bool = false
        SUNgenerator::Union{Nothing,Generator}
        _cloverloops::Array{Wilson_loop_set,2}
        smearing::SmearingParam 

        function FermiActionParam_WilsonClover(hop,r,eps,Dirac_operator,MaxCGstep,
            Clover_coefficient,internal_flags,inn_table,_ftmp_vectors,
            _is1,_is2,
            quench, SUNgenerator,_cloverloops;smearingparameters = "nothing",
            loops_list = nothing,
            coefficients  = nothing,
            numlayers = 1,
            L = nothing)

            smearing = construct_smearing(smearingparameters,loops_list,L,coefficients,numlayers)
            
            #if smearingparameters == nothing
            #    smearing = Nosmearing()
            #end
            #smearing = Nosmearing()

            return new(hop,r,eps,Dirac_operator,MaxCGstep,
            Clover_coefficient,internal_flags,inn_table,_ftmp_vectors,
            _is1,_is2,
            quench, SUNgenerator,_cloverloops,smearing)
        end
    end


    function construct_smearing(smearingparameters,loops_list,L,coefficients,numlayers)
        if smearingparameters == "nothing"
            smearing = Nosmearing()
        else
            @assert loops_list != nothing "loops should be put if you want to use smearing schemes"
            loops = make_loops(loops_list,L)

            @assert coefficients != nothing "coefficients should be put if you want to use smearing schemes"
            println("stout smearing will be used")
            if numlayers == 1
                smearing = SmearingParam_stout(loops,coefficients)
            else
                numloops = length(loops)
                smearing_single = SmearingParam_stout(loops,rand(numloops))
                smearing = SmearingParam_stout_multi(smearing_single.staples_for_stout,
                    smearing_single.tensor_derivative,
                    smearing_single.staples_for_stout_dag,
                    smearing_single.tensor_derivative_dag,
                    coefficients
                    )

            end
            #println(smearing )
            #exit()
        end
        return smearing
    end

    Base.@kwdef struct FermiActionParam_Staggered <: FermiActionParam
        mass::Float64 = 0.5
        eps::Float64 = 1e-19
        Dirac_operator::String = "Staggered"
        MaxCGstep::Int64 = 3000 
        quench::Bool = false
        Nf::Int8 = 4
        rhmc_action::Union{Nothing,RHMC}
        rhmc_MD::Union{Nothing,RHMC}
        smearing::SmearingParam



        function FermiActionParam_Staggered(
            mass,
            eps,
            Dirac_operator,
            MaxCGstep,
            quench,
            Nf;smearingparameters = "nothing",
            loops_list = nothing,
            coefficients  = nothing,
            numlayers = 1,
            L = nothing
            ) where T <: Real

            if Nf == 4 || Nf == 8 # 8 flavors if phi (Mdag M)^{-1} phi
                rhmc_action = nothing
                rhmc_MD = nothing
            else
                #for action: r_action
                #Nf = 8 -> alpha = 1 -> power x^{1/2} 
                #Nf = 2 -> alpha = 1/4 -> power x^1/8 
                #Nf = 1 -> alpha = 1/8  -> power x^1/16 
                order = Nf //16

                rhmc_action = RHMC(order,n=15)

                #for MD: r_MD
                #Nf = 8 -> alpha = 1 -> power x^{1} 
                #Nf = 2 -> alpha = 1/4 -> power x^1/4 
                #Nf = 1 -> alpha = 1/8  -> power x^1/8 
                order = Nf // 8
                #rhmcorder = 8 ÷ Nf
                rhmc_MD = RHMC(order,n=10)
            end

            smearing = construct_smearing(smearingparameters,loops_list,L,coefficients,numlayers)


            return new(
            mass,
            eps,
            Dirac_operator,
            MaxCGstep,
            quench,
            Nf,
            rhmc_action,
            rhmc_MD,
            smearing
            )
        end
    end


    function GaugeActionParam_autogenerator(βs,loops,NC,couplinglist)
        @assert length(βs) == length(loops) "The number of loops should be the number of βs!"
        numactions = length(loops)
        β = βs[1]
        staples = Array{Array{Wilson_loop_set,1},1}(undef,numactions)
        for (i,loop) in enumerate(loops)
            staples[i] = make_staples(loop)
            #=
            println("$i-th action")
            display(loop)
            println("$i-th action's staple")
            for mu=1:4
                println("$mu -direction")
                display(staples[i][mu])
            end
            =#
        end

        return GaugeActionParam_autogenerator(βs,β,numactions,NC,loops,staples,couplinglist)
    end

    Base.@kwdef struct FermiActionParam_Domainwall <: FermiActionParam
        N5::Int64
        r::Float64 = 1
        M::Float64 = -1
        m::Float64
        ωs::Array{Float64,1}
        b::Float64 
        c::Float64
        eps::Float64 = 1e-19
        Dirac_operator::String = "Domainwall"
        MaxCGstep::Int64 = 3000 
        quench::Bool = false
        smearing::SmearingParam 
        

        function FermiActionParam_Domainwall(N5,r,M,m,ωs,b,c,eps,Dirac_operator,MaxCGstep,quench
            ;smearingparameters = "nothing",
            loops_list = nothing,
            coefficients  = nothing,
            numlayers = 1,
            L = nothing)

            smearing = construct_smearing(smearingparameters,loops_list,L,coefficients,numlayers)
            #smearing = Nosmearing()
            #if smearingparameters == nothing
            #    smearing = Nosmearing()
            #end
            return new(N5,r,M,m,ωs,b,c,eps,Dirac_operator,MaxCGstep,quench,smearing)
        end

        function FermiActionParam_Domainwall(N5,r,M,m,eps,Dirac_operator,MaxCGstep,quench
            ;smearingparameters = "nothing",
            loops_list = nothing,
            coefficients  = nothing,
            numlayers = 1,
            L = nothing)

            b = 1
            c = 1
            ωs = ones(Float64,Ns)

            smearing = construct_smearing(smearingparameters,loops_list,L,coefficients,numlayers)
            #smearing = Nosmearing()
            #if smearingparameters == nothing
            #    smearing = Nosmearing()
            #end
            return new(N5,r,M,m,ωs,b,c,eps,Dirac_operator,MaxCGstep,quench,smearing)
        end


    end

    function show_parameters_action(fparam::FermiActionParam_Staggered)
        println("#--------------------------------------------------")
        println("#Fermion Action parameters")
        println("#type: ",typeof(fparam))
        println("mass = ",fparam.mass)
        println("eps = ",fparam.eps)
        println("Dirac_operator = ",fparam.Dirac_operator)
        println("MaxCGstep = ",fparam.MaxCGstep)
        println("quench = ",fparam.quench)
        println("Nf = ",fparam.Nf)
        println("#--------------------------------------------------")
    end

    function show_parameters_action(fparam::FermiActionParam_Wilson)
        println("#--------------------------------------------------")
        println("#Fermion Action parameters")
        println("#type: ",typeof(fparam))
        println("hop = ",fparam.hop)
        println("r = ",fparam.r)
        println("eps = ",fparam.eps)
        println("Dirac_operator = ",fparam.Dirac_operator)
        println("MaxCGstep = ",fparam.MaxCGstep)
        println("quench = ",fparam.quench)
        println("#--------------------------------------------------")
    end

    function show_parameters_action(fparam::FermiActionParam_WilsonClover)
        println("#--------------------------------------------------")
        println("#Fermion Action parameters")
        println("#type: ",typeof(fparam))
        println("hop = ",fparam.hop)
        println("r = ",fparam.r)
        println("eps = ",fparam.eps)
        println("Dirac_operator = ",fparam.Dirac_operator)
        println("MaxCGstep = ",fparam.MaxCGstep)
        println("Clover_coefficient = ",fparam.Clover_coefficient)
        println("quench = ",fparam.quench)
        println("#--------------------------------------------------")
    end

    function show_parameters_action(gparam::GaugeActionParam_standard)
        println("#--------------------------------------------------")
        println("#Gauge Action parameters")
        println("#type: ",typeof(gparam))
        println("β = ",gparam.β)
        println("NC = ",gparam.NTRACE)
        println("#--------------------------------------------------")
    end

    function show_parameters_action(gparam::GaugeActionParam_autogenerator)
        println("#--------------------------------------------------")
        println("#Gauge Action parameters")
        println("#type: ",typeof(gparam))
        println("#Num. of action terms: ",gparam.numactions)
        println("#coupling βs = ",gparam.βs)
        #=
        println("#actions that we consider: ")
        for (i,loop) in enumerate(gparam.loops)
            println("#------------------------------")
            println("#$i-th action term consists of")
            display(loop)
            println("#------------------------------")
        end
        =#
        println("NC = ",gparam.NTRACE)        
        println("#--------------------------------------------------")
    end

    

    function FermiActionParam_WilsonClover(hop,r,eps,MaxCGstep,NV,Clover_coefficient,NC;quench=false)
        #CloverFμν = zeros(ComplexF64,3,3,NV,6)
        inn_table= zeros(Int64,NV,4,2)
        internal_flags = zeros(Bool,2)
        _ftmp_vectors = Array{Array{ComplexF64,3},1}(undef,6)
        _is1 = zeros(Int64,NV)
        _is2 = zeros(Int64,NV)
        for i=1:6
            _ftmp_vectors[i] = zeros(ComplexF64,3,NV,4)
        end
        #return FermiActionParam_WilsonClover(hop,r,eps,"WilsonClover",MaxCGstep,Clover_coefficient,CloverFμν,inn_table,internal_flags,_ftmp_vectors,_is1,_is2,quench)
        if NC ≥ 4
            SUNgenerator = Generator(NC)
        else
            SUNgenerator = nothing
        end

        _cloverloops = Array{Wilson_loop_set,2}(undef,3,4)
        for μ=1:3
            for ν=μ+1:4
                _cloverloops[μ,ν] = make_cloverloops(μ,ν)
            end
        end

        return FermiActionParam_WilsonClover(hop,r,eps,"WilsonClover",MaxCGstep,Clover_coefficient,inn_table,internal_flags,_ftmp_vectors,_is1,_is2,quench,
                        SUNgenerator,_cloverloops)
    end

    function FermiActionParam_Wilson(hop,r,eps,MaxCGstep;quench=false)
        return FermiActionParam_Wilson(hop,r,eps,"Wilson",MaxCGstep,quench)
    end

    function FermiActionParam_Wilson(hop,r,eps,Dirac,MaxCGstep;quench=false)
        return FermiActionParam_Wilson(hop,r,eps,Dirac,MaxCGstep,quench)
    end

    """
    ```Setup_Fermi_action(Dirac_operator= "Wilson")```

    Set up the information about the Fermion action.

    Now only WilsonFermion case is supported.

    # For example
    ```julia
        fparam = Setup_Fermi_action()
    ```

    The default values are 

    ```julia
    hop::Float64  = 0.141139
    r::Float64  = 1
    eps::Float64 = 1e-19
    Dirac_operator::String = "Wilson"
    MaxCGstep::Int64 = 3000
    ```

    
    - hop : hopping parameter
    - r : Wilson term
    - eps : convergence criteria in the CG method
    - MaxCGstep : maximum number of the CG steps

    If you want to change the parameters for the Wilson Fermions, 
    please do as follows.

    ```julia
        fparam = FermiActionParam_Wilson(hop,r,eps,MaxCGstep)
    ```

    """
    function Setup_Fermi_action(Dirac_operator= "Wilson")
        if Dirac_operator == "Wilson"
            return FermiActionParam_Wilson()
        end
    end



    function SmearingParam_stout(loops_smearing,ρs)
        num = length(loops_smearing)
        @assert num == length(ρs) "number of ρ elements in stout smearing scheme should be $num. Now $(length(ρs))"
        staplesforsmear_set = Array{Wilson_loop_set,1}[]
        staplesforsmear_dag_set = Array{Wilson_loop_set,1}[]
        println("staple for stout smearing")

        tensor_derivative = Array{Tensor_derivative_set,1}(undef,num)
        tensor_derivative_dag = Array{Tensor_derivative_set,1}(undef,num)
        


        for i=1:num
            loop_smearing = loops_smearing[i]

            staplesforsmear = Array{Wilson_loop_set,1}(undef,4)
            staplesforsmear_dag = Array{Wilson_loop_set,1}(undef,4)
            


            staple = make_staples(loop_smearing)

            for μ=1:4
                staplesforsmear_dag[μ] = staple[μ]##make_plaq_staple(μ)
                staplesforsmear[μ] = staplesforsmear_dag[μ]'
                #println("$μ -direction")
                #display(staplesforsmear[μ])
                #staplesforsmear[μ] = make_plaq_staple(μ)
                #staplesforsmear_dag[μ] = staplesforsmear[μ]'
                #println("dagger: $μ -direction")
                #display(staplesforsmear_dag[μ])
            end
            tensor_derivative[i] = Tensor_derivative_set(staplesforsmear)
            tensor_derivative_dag[i] = Tensor_derivative_set(staplesforsmear_dag)

            push!(staplesforsmear_set,staplesforsmear )
            push!(staplesforsmear_dag_set,staplesforsmear_dag)

        end

        return SmearingParam_stout(
            staplesforsmear_set, 
            tensor_derivative, 
            staplesforsmear_dag_set, 
            tensor_derivative_dag,
            ρs 
            ) 
    end



end