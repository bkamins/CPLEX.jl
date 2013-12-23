function optimize!(model::Model)
  @assert is_valid(model.env)
  if model.has_int
    stat = @cpx_ccall(mipopt, Cint, (Ptr{Void}, Ptr{Void}), model.env.ptr, model.lp)
  elseif model.has_qc
    stat = @cpx_ccall(qpopt, Cint, (Ptr{Void}, Ptr{Void}), model.env.ptr, model.lp)
  else
    stat = @cpx_ccall(lpopt, Cint, (Ptr{Void}, Ptr{Void}), model.env.ptr, model.lp)
  end
  if stat != 0
    throw(CplexError(model.env, stat))
  end
end

function get_objval(model::Model)
  objval = Array(Cdouble, 1)
  stat = @cpx_ccall(getobjval, Cint, (
                    Ptr{Void},
                    Ptr{Void},
                    Ptr{Cdouble}
                    ),
                    model.env.ptr, model.lp, objval)
  if stat != 0
    throw(CplexError(model.env, stat))
  end
  return objval
end

function get_solution(model::Model)
  nvars = num_var(model)
  x = Array(Cdouble, nvars)
  stat = @cpx_ccall(getx, Cint, (
                    Ptr{Void},
                    Ptr{Void},
                    Ptr{Cdouble},
                    Cint,
                    Cint
                    ),
                    model.env.ptr, model.lp, x, 0, nvars-1)
  if stat != 0
    throw(CplexError(model.env, stat))
  end
  return x
end

function get_reduced_costs(model::Model)
    nvars = num_var(model)
    p = Array(Cdouble, nvars)
    status = Array(Cint, 1)
    stat = @cpx_ccall(getdj, Cint, (
                      Ptr{Void}, 
                      Ptr{Void}, 
                      Ptr{Cdouble}, 
                      Cint, 
                      Cint
                      ),
                      model.env.ptr, model.lp, p, 0, nvars-1)
    if stat != 0
       throw(CplexError(model.env, stat))
   end
   return p
end

function get_constr_duals(model::Model)
    ncons = num_constr(model)
    p = Array(Cdouble, ncons)
    status = Array(Cint, 1)
    stat = @cpx_ccall(getpi, Cint, (
                      Ptr{Void}, 
                      Ptr{Void}, 
                      Ptr{Cdouble}, 
                      Cint, 
                      Cint
                      ),
                      model.env.ptr, model.lp, p, 0, ncons-1)
    if stat != 0
       throw(CplexError(model.env, stat))
   end
   return p
end

function get_constr_solution(model::Model)
  ncons = num_constr(model)
  Ax = Array(Cdouble, ncons)
  stat = @cpx_ccall(getax, Cint, (
                    Ptr{Void},
                    Ptr{Void},
                    Ptr{Cdouble},
                    Cint,
                    Cint
                    ),
                    model.env.ptr, model.lp, Ax, 0, ncons-1)
  if stat != 0
    throw(CplexError(model.env, stat))
  end
  return Ax
end

function get_infeasibility_ray(model::Model)
  ncons = num_constr(model)
  y = Array(Cdouble, ncons)
  proof_p = Array(Cdouble, 1)
  stat = @cpx_ccall(dualfarkas, Cint, (
                    Ptr{Void},
                    Ptr{Void},
                    Ptr{Cdouble},
                    Ptr{Cdouble}
                    ),
                    model.env.ptr, model.lp, y, proof_p)
  if stat != 0
    throw(CplexError(model.env, stat))
  end
  return y
end

function get_unbounded_ray(model::Model)
  n = num_var(model)
  z = Array(Cdouble, n)
  stat = @cpx_ccall(getray, Cint, (
                    Ptr{Void},
                    Ptr{Void},
                    Ptr{Cdouble}
                    ),
                    model.env.ptr, model.lp, z)
  if stat != 0
    throw(CplexError(model.env, stat))
  end
  return z
end

const status_symbols = [
    1   => :CPX_STAT_OPTIMAL,
    2   => :CPX_STAT_UNBOUNDED,
    3   => :CPX_STAT_INFEASIBLE,
    4   => :CPX_STAT_INForUNBD,
    5   => :CPX_STAT_OPTIMAL_INFEAS,
    6   => :CPX_STAT_NUM_BEST,
    7   => :CPX_STAT_FEASIBLE_RELAXED,
    8   => :CPX_STAT_OPTIMAL_RELAXED,
    10  => :CPX_STAT_ABORT_IT_LIM,
    11  => :CPX_STAT_ABORT_TIME_LIM,
    11  => :CPX_STAT_ABORT_OBJ_LIM,
    13  => :CPX_STAT_ABORT_USER,
    20  => :CPX_STAT_OPTIMAL_FACE_UNBOUNDED,
    21  => :CPX_STAT_ABORT_PRIM_OBJ_LIM,
    22  => :CPX_STAT_ABORT_DUAL_OBJ_LIM,
    101 => :CPXMIP_OPTIMAL,
    102 => :CPXMIP_OPTIMAL_TOL,
    103 => :CPXMIP_INFEASIBLE,
    104 => :CPXMIP_SOL_LIM,
    105 => :CPXMIP_NODE_LIM_FEAS,
    106 => :CPXMIP_NODE_LIM_INFEAS,
    107 => :CPXMIP_TIME_LIM_FEAS,
    108 => :CPXMIP_TIME_LIM_INFEAS,
    109 => :CPXMIP_FAIL_FEAS,
    110 => :CPXMIP_FAIL_INFEAS,
    111 => :CPXMIP_MEM_LIM_FEAS,
    112 => :CPXMIP_MEM_LIM_INFEAS,
    113 => :CPXMIP_ABORT_FEAS,
    114 => :CPXMIP_ABORT_INFEAS,
    115 => :CPXMIP_OPTIMAL_INFEAS,
    116 => :CPXMIP_FAIL_FEAS_NO_TREE,
    117 => :CPXMIP_FAIL_INFEAS_NO_TREE,
    118 => :CPXMIP_UNBOUNDED,
    119 => :CPXMIP_INForUNBD,
    120 => :CPXMIP_FEASIBLE_RELAXED,
    121 => :CPXMIP_OPTIMAL_RELAXED
]

get_status(model::Model) = status_symbols[int(get_status_code(model))]::Symbol
get_status_code(model::Model) = @cpx_ccall(getstat, Cint, (Ptr{Void}, Ptr{Void}), model.env.ptr, model.lp)
