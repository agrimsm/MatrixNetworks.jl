using DataStructures
import IterTools 

# From Julia's v0.6 reslease notes:
# The Collections module has been removed, and all functions defined 
# therein have been moved to the DataStructures package (#19800).
"""
`erdos_renyi_undirected`
========================

Generate an undirected Erdős-Rényi graph.
An undirected  
Erdős-Rényi graph is generated by letting each
undirected edge between `n` nodes
be present with probability `p`.

There is another form of the call where the
input is the average degree of the generated
graph. 

**The current implementation uses sprand, this may change in the future.**
**Do not depend on this routine for reliable output between versions.**

Input
-----
- `n`: the number of nodes
- `p`: the probability of an edge, or the average degree. 
   if \$`p` >= 1\$, then \$`p`\$ is interpreted as an average degree
   instead of a probability. (There is no point in generating
   an Erdős-Rényi graph with probability \$`p`=1\$)
- `d`: The desired average degree, converted into a probabiltity 
   via d/n
   
Functions
---------
- `erdos_renyi_undirected(n::Int,p::Float64)` specify the 
  probability or average degree
- `erdos_renyi_undirected(n::Int,d::Int)` specify the average degree directly         

Output
------
- A matrix network type for the Erdős-Rényi graph.

Example
-------
~~~~ 
# show the connected phase transition
n = 100
avgdegs = linspace(1.,2*log(n),100) 
compsizes = map( (dbar) -> 
        maximum(scomponents(erdos_renyi_undirected(n,dbar)).sizes),
    avgdegs )
using Plots
unicodeplots()
plot(avgdegs,compsizes,xaxis=("average degree"),yaxis=("largest component size"))    
~~~~    
"""
function erdos_renyi_undirected(n::Int, p::Float64)
    if p < 0 || p > n throw(DomainError(p)) end

    if p >= 1. # interpret as average degree
        p = p/n # convert to probability
    end
    if isnan(p)
        return _matrix_network_direct(spzeros(n,n),1)
    end
    A = sprand(n,n,p)
    if n > 0
        Aup = triu(A,1)
    else
        Aup = A
    end
    Asym = max.(Aup,Aup')
    return _matrix_network_direct(Asym,1)
end
erdos_renyi_undirected(n::Int, d::Int) = erdos_renyi_undirected(n, d/n)

erdős_rényi_undirected = erdos_renyi_undirected 

"""
`erdos_renyi_directed`
========================

Generate an directed Erdős-Rényi graph. A directed 
Erdős-Rényi graph is generated by letting each
directed edge between `n` nodes
be present with probability `p`.

There is another form of the call where the
input is the average degree of the generated
graph. 

**The current implementation uses sprand, this may change in the future.**
**Do not depend on this routine for reliable output between versions.**


Input
-----
- `n`: the number of nodes
- `p`: the probability of an edge.
- `d`: the average degree 

Functions
---------
- `erdos_renyi_directed(n::Int,p::Float64)` specify the probability
  (p < 1.) or the average degree (p >= 1.) 
- `erdos_renyi_directed(n::Int,d::Int)` specify the average degree
  directly 

Output
------
- A matrix network type for the Erdős-Rényi graph. 
"""
function erdos_renyi_directed(n::Int, p::Float64)
    if p < 0 || p > n throw(DomainError(p)) end
    if p >= 1. # interpret as average degree
        p = p/n # convert to probability
    end
    if isnan(p)
        return _matrix_network_direct(spzeros(n,n))
    end
    
    A = sprand(n,n,p)
    
    # return _matrix_network_direct(A-spdiagm(diag(A),0)) # directions don't matter
    return _matrix_network_direct(A-spdiagm(0 => diag(A))) # directions don't matter
end

erdos_renyi_directed(n::Int, d::Int) = erdos_renyi_directed(n,d/n)

erdős_rényi_directed = erdos_renyi_directed

"""
`chung_lu_undirected`
========================

Generate an approximate undirected Chung-Lu graph. The approximation is because we draw
exactly |E| edges where each edge is sampled from the Chung-Lu model. But then
we discard duplicate edges and self-loops. So the new graph will always have fewer
edges than the input degree sequence.

**This will likely change in future versions and provide an exact Chung-Lu model.**

If the graph is 

Usage
-----
- `chung_lu_undirected(d)`
- `chung_lu_undirected(d,nedges)` 

Input
-----
- `d`: the degree sequence vector. This vector is non-negative and has the expected
degree for each vertex.

Output
------
- A MatrixNetwork for the undirected graph that results from the Chung-Lu sample.

Example
-------
~~~~
A = load_matrix_network("tapir")
d = vec(sum(A,1))
B = sparse(chung_lu_undirected(d))
nnz(A)
nnz(B)
~~~~

"""
function chung_lu_undirected end

function chung_lu_undirected(d::Vector{Int})
    chung_lu_undirected(d, floor(Int,sum(d)/2))
end

function chung_lu_undirected(d::Vector{Int}, nedges::Int)
    n = length(d)

    # TODO find some standard function for this
    for v in d
        if v < 0
            throw(DomainError(v))
        end
    end
    
    if nedges < 0 || nedges > div(n*(n-1),2)
        throw(ArgumentError("nedges $nedges is too large for $n node undirected graph")) 
    end
    
    nodevec = zeros(Int,sum(d))
    curedge = 1
    for i=1:n
        for j=1:d[i]
            nodevec[curedge] = i
            curedge += 1
        end
    end
    
    ei, ej = unique_edge_sample_undirected(nodevec, nedges)
    A = sparse(ei,ej,1.,n,n)

    return _matrix_network_direct(A) # avoid the transpose  
end

function unique_edge_sample_undirected(nodevec, nedges::Int)
    edges = Set{Tuple{Int,Int}}()
    sizehint!(edges, nedges)
        
    curedges = 0
    while curedges < nedges
        src = rand(nodevec)
        dst = rand(nodevec)
        if src == dst
            continue
        else
            # fix the order 
            if src < dst
                dst, src = src, dst
            end
            if !((src,dst) in edges)
                push!(edges, (src,dst))
                curedges += 1
            end
        end
    end

    ei = zeros(Int,nedges*2)
    ej = zeros(Int,nedges*2)
    
    k = 1
    for edge in edges
        ei[k] = edge[1]
        ej[k] = edge[2]
        k+=1    
        ei[k] = edge[2]
        ej[k] = edge[1]
        k+=1
    end
    
    return ei, ej
end

"""
Not public right now
"""
function _chung_lu_dense_undirected(d::Vector{Int})
    M = zeros(Int,n,n)
    idenom = 1/sum(d)
    for i=1:n
        for j=i+1:n
            if rand(Float64) < d[i]*d[j]*idenom
                M[i,j] = 1
            end
        end
    end
    M = M + M'
    return _matrix_network_direct(sparse(M))
end

"""
The internal Havel-Hakimi function has an optional store
behavior that saves the edges as they come out of the algorithm.
This enables us to generate a Havel Hakimi graph, which can
be useful.
"""
function _havel_hakimi(degs::Vector{Int}, store::Bool, ei::Vector{Int}, ej::Vector{Int})
    q = PriorityQueue{Int,Int}(Base.Order.Reverse)
    n = length(degs)
    effective_n = n
    degsum = 0
    dmax = 0
    for (i,d) in enumerate(degs)
        q[i] = d
        degsum += d
        dmax = max(d,dmax)
        if d < 0
            throw(ArgumentError("the degree sequence must be non-negative"))
        end
    end
    
    if mod(degsum,2) != 0; return false; end
    if n > 0 && dmax >= n; return false; end # n > 0 checks for the empty graph
    
    if store
        resize!(ei,degsum)
        resize!(ej,degsum)
    end
    
    dlist = Vector{Pair{Int,Int}}(undef,dmax)
    enum = 1
    
    while !isempty(q)
        vi,d = peek(q) # vi is the cur vertex, d is the cur deg
        dequeue!(q)    # remove it
        for n=1:d                  # make a list of each neighbor
            if isempty(q); return false; end
            dlist[n] = peek(q)
            dequeue!(q)
        end
        # now "add" an edge from vi->neighbor, and thus, decrease it's 
        # degree when we re-add it
        for n=1:d
            if store
                ei[enum] = vi
                ej[enum] = dlist[n][1]
                enum += 1
                ei[enum] = dlist[n][1]
                ej[enum] = vi
                enum += 1
            end
            if dlist[n][2] < 1
                return false
            elseif dlist[n][2] == 1
                # don't both re-adding the vertex
            else
                q[dlist[n][1]] = dlist[n][2] - 1
            end
        end
    end
    return true
end

"""
`is_graphical_sequence`
=======================

Check whether or not a degree sequence is graphical,
which means that it is a valid degree sequence for 
an undirected graph.

Note that this does not mean it is a valid degree
sequence for a connected undirected graph. So,
for instance, 
`[1,1,1,1]` 
is a valid degree sequence for two
disconnected edges

Usage
-----
`is_graphical_sequence(d)` returns true or false 

Input
-----
- `d::Vector{Int}`:  a vector of integer valued degrees

Output
------
- a boolean that is true if the sequence is graphical
""" 
function is_graphical_sequence(d::Vector{Int})
    return _havel_hakimi(d, false, Int[],Int[])
end


"""
`havel_hakimi_graph`
====================

Create a graph with a given degree sequence 

Usage
-----
`A = havel_hakimi_graph(d)` returns an instance of the 
a graph with degree sequence d or throws ArgumentError
if the degree sequence is not graphical.   

Input
-----
- `d::Vector{Int}`:  a vector of integer valued degrees

Output
------
-`A`: a matrix network for the undirected graph that
results from the Havel-Hakimi procedure.
""" 
function havel_hakimi_graph(d::Vector{Int})
    ei = Int[]
    ej = Int[]
    if _havel_hakimi(d, true, ei, ej) == false
        throw(ArgumentError("the degree sequence is not graphical"))
    end
    return MatrixNetwork(ei,ej,length(d))
end

"""
`preferential_attachment_graph`
===============================

Generate an instance of a preferential attachment
graph. This is an undirected graph that is generated
as follows:

* Start with a k0-node clique. 
* Add n-k0 vertices where 
     each vertex links to k nodes chosen
     based their degree (and repeats
     are allowed).

Functions
---------
The following functions are synonyms

- `preferential_attachment_graph`
- `pa_graph`

and

- `preferential_attachment_edges!`
- `pa_edges!`

The computational functions are

- `pa_graph(n,k,k0)` Generate a PA graph with a k0 node clique
  and n total nodes and k edges added per node. This returns
  a MatrixNetwork type

The edge functions are
  
- `pa_edges!(nnew,k,edges)` Add new edges to an 
  existing set by adding `nnew` nodes to the set of edges
  where each node picks k edges based on the degrees. The
  new node ids are based on the largest entry in the edges
  array. 
- `pa_edges!(nnew,k,edges,n0)` Generate a set of edges total`
  nodes to the set of edges where n0+1 is the starting index
  for the new set of nodes   
     
Input
-----
- `n`: the number of nodes in the final graph
- `k`: the number of links picked by each node when it is added.
  The actual degree can be larger or smaller than this number because
  of links from other nodes or duplicates selected. 
- `k0`: The number of nodes in the starting clique. 
- `edges`: A list of edges to be manipulated in the process of 
 generating new edges. 

Output
------
- A matrix network type for the preferential attachment graph.
- `edges` An updated list of edges. 

Example
-------
~~~~ 
pa_graph(100,5,2)
~~~~    
"""
:preferential_attachment_graph, :pa_graph, :pa_edges!, :preferential_attachment_edges!

function preferential_attachment_graph(n::Int,k::Int,k0::Int)
    #n >= 0 || throw(ArgumentError(@sprintf("n=%i must be non-negative",n)))
    #k >= 1 || throw(ArgumentError(@sprintf("k=%i must be strictly positive",k0)))
    k0 >= 0 || throw(ArgumentError(@sprintf("k0=%i must be non-negative",n)))
    n >= k0 || throw(ArgumentError(@sprintf("n=%i must be >= k0=%i",n, k0)))
    #k >= 0 || throw(ArgumentError(@sprintf("k=%i must be non-negative",k)))
    edges = Vector{Tuple{Int,Int}}()
    # add the clique
    for i=1:k0
        for j=1:i-1
            push!(edges, (i,j))
            push!(edges, (j,i))
        end
    end
    return MatrixNetwork(preferential_attachment_edges!(n-k0,k,edges,k0),n)
end

function preferential_attachment_edges!(nnew::Int,k::Int,edges::Vector{Tuple{Int,Int}})
    if length(edges) == 0
        throw(ArgumentError("the list of initial edges must be non-empty"))
    end
    n0 = max(edges[1]...)
    for j=2:length(edges)
        n0 = max(n0,edges[j]...)
    end
    return preferential_attachment_edges!(nnew,k,edges,n0)
end

function preferential_attachment_edges!(
            nnew::Int,k::Int,edges::Vector{Tuple{Int,Int}},n0::Int)
    for iter=1:nnew
        i = n0+iter
        newedges = unique([rand(edges)[1] for j=1:k])
        for v in newedges
            push!(edges, (i, v))
            push!(edges, (v, i))
        end
    end
    return edges
end

pa_graph = preferential_attachment_graph
pa_edges! = preferential_attachment_edges!

"""
'generalized_preferential_attachment_graph'
===========================================

Generate an instance of a generalized preferential attachment graph which
follows the Avin,Lotker,Nahum,Peleg description. This is an undirected graph
that is generated as follows:

- Start with a k0-node clique
- Add n - k0 vertices where at each time step one of three events occurs: A new
node is added with probability p, a new edge between two existing nodes is added
with probability r, two new nodes with an edge between them is added with
probability 1 - p - r

Functions
---------
The following functions are synonyms

- 'generalized_preferential_attachment_graph'
- 'gpa_graph'

and

- 'generalized_preferential_attachment_edges!'
- 'gpa_edges!'

The computational functions are

- 'gpa_graph(n,p,r,k0)' Generate a GPA graph with a k0 clique and n total nodes.
    This returns a MatrixNetwork type
- 'gpa_graph(n,p,r,k0,Val{true})' Generate a GPA graph with a k0 clique and
    n total nodes, allowing self-loops. This returns a MatrixNetwork type

The edge functions are

-   'gpa_edges!(n,p,r,edges,n0)' Add new edges to an existing set, by taking
    n0 time steps. Edges are added in one of three ways: From a new node to
    an existing node with probability p, between two existing nodes with
    probability r, between two new nodes with probability 1-p-r
-   'gpa_edges!(n,p,r,edges,n0,Val{true})' Add new edges to an existing set, by
    taking n0 time steps. Edges are added in one of three ways: From a new node
    to an existing node with probability p, between two existing nodes with
    probability r (allowing self-loops), between two new nodes with probability
    1-p-r

Input
-----
- 'n': the number of nodes in the final graph.
- 'p': The probability of a node event, p must be a constant.
- 'r': The probability of an edge event, r must be a constant. p+r <=1
- 'k0': the number of nodes in the starting clique.
- 'Val{true}': Include this parameter if self-loops are allowed. Default is false
- 'edges': A list of edges to be manipulated in the process of generating
          new edges.

Output
------
- A matrix network type for the generalized preferential attachment graph.
- 'edges': An updated list of edges.

Example:
generalized_preferential_attachment_graph(100,1/3,1/2,2)

"""
:generalized_preferential_attachment_graph, :gpa_graph, 
:generalized_preferential_attachment_edges!, :gpa_edges!

generalized_preferential_attachment_graph(n::Int,p::Float64,r::Float64,k0::Int) =
    generalized_preferential_attachment_graph(n,p,r,k0,Val{false})
generalized_preferential_attachment_edges!(n::Int,p::Float64,r::Float64,edges::Vector{Tuple{Int,Int}},n0::Int) =
    generalized_preferential_attachment_edges!(n,p,r,edges,n0,Val{false})

function generalized_preferential_attachment_graph(
    n::Int,p::Float64,r::Float64,k0::Int,::Type{Val{true}})
    k0 >= 0 || throw(ArgumentError(@sprintf("k0=%i must be non-negative",k0)))
    n >= k0 || throw(ArgumentError(@sprintf("n=%i must be >= k0=%i",n,k0)))
    0<=p<=1 || throw(ArgumentError(@sprintf("p=%0.3f must be between 0 and 1",p)))
    0<=r<=1 || throw(ArgumentError(@sprintf("r=%0.3f must be between 0 and 1",r)))
    p+r <= 1 || throw(ArgumentError(@sprintf("(p=%0.3f)+(r=%0.3f) must be <=1",p,r)))
    edges = Vector{Tuple{Int,Int}}()
    #add the clique
    for i = 1:k0
        for j = 1:i-1
            push!(edges,(i,j))
            push!(edges, (j,i))
        end
    end
    return MatrixNetwork(generalized_preferential_attachment_edges!(n,p,r,edges,k0,Val{true}),n)
end

function generalized_preferential_attachment_graph(
    n::Int,p::Float64,r::Float64,k0::Int,::Type{Val{false}})
    k0 >= 0 || throw(ArgumentError(@sprintf("k0=%i must be non-negative",k0)))
    n >= k0 || throw(ArgumentError(@sprintf("n=%i must be >= k0=%i",n,k0)))
    0<=p<=1 || throw(ArgumentError(@sprintf("p=%0.3f must be between 0 and 1",p)))
    0<=r<=1 || throw(ArgumentError(@sprintf("r=%0.3f must be between 0 and 1",r)))
    p+r <= 1 || throw(ArgumentError(@sprintf("(p=%0.3f)+(r=%0.3f) must be <=1",p,r)))
    edges = Vector{Tuple{Int,Int}}()
    #add the clique
    for i = 1:k0
        for j = 1:i-1
            push!(edges,(i,j))
            push!(edges, (j,i))
        end
    end
    return MatrixNetwork(generalized_preferential_attachment_edges!(n,p,r,edges,k0,Val{false}),n)
end

function generalized_preferential_attachment_edges!(
    n::Int,p::Float64,r::Float64,edges::Vector{Tuple{Int,Int}},n0::Int,::Type{Val{true}})
    i = n0
    while i < n
        #generate a random value between 0 and 1
        x = rand()
        if x < p #node event
            v = rand(edges)[1]
            push!(edges, (i+1,v[1]))
            push!(edges, (v[1], i+1))
            i = i+1;
        elseif x < p+r #edge event, self loops permitted
            v1 = rand(edges)[1]
            v2 = rand(edges)[1]
            push!(edges, (v1, v2))
            push!(edges, (v2, v1))
        else #component event
            if i+2 <= n #only allow this step if there is room for two more nodes
                push!(edges, (i+1, i+2))
                push!(edges, (i+2, i+1))
                i = i+2;
            end
        end
    end
    return edges
end

function _check_for_two_distinct_nodes(edges::Vector{Tuple{Int,Int}})
    length(edges) > 0 || throw(ArgumentError("requires at least one edge"))
    firstnode = edges[1][1]
    return any(IterTools.imap(x -> firstnode != x[1] || firstnode != x[2], edges))
end

function generalized_preferential_attachment_edges!(
    n::Int,p::Float64,r::Float64,edges::Vector{Tuple{Int,Int}},n0::Int,::Type{Val{false}})
    i = n0
    if i >= n
        return edges
    end
    
    if !_check_for_two_distinct_nodes(edges::Vector{Tuple{Int,Int}})
        throw(ArgumentError("The starting graph must have at least two distinct nodes"))
    end

    while i < n
        #generate a random value between 0 and 1
        x = rand()
        if x < p #node event
            v = rand(edges)[1]
            push!(edges, (i+1,v[1]))
            push!(edges, (v[1], i+1))
            i = i+1;
        elseif x < p+r #edge event, no self-loops permitted
            v1 = rand(edges)[1]
            v2 = rand(edges)[1]
            while (v1 == v2 && i != 1) #i != 1 because we want more than 1 node for this to work
                v1 = rand(edges)[1]
                v2 = rand(edges)[1]
            end
            push!(edges, (v1, v2))
            push!(edges, (v2, v1))
        else #component event
            if i+2 <= n #only allow this step if there is room for two more nodes
                push!(edges, (i+1, i+2))
                push!(edges, (i+2, i+1))
                i = i+2;
            end
        end
    end
    return edges
end

gpa_graph = generalized_preferential_attachment_graph
gpa_edges! = generalized_preferential_attachment_edges!

"""
`roach_graph`
=============

Generate a roach graph on 4n vertices which follows the Guattery-Miller 
description. The roach graph has a body that consists of 2n vertices which
ard two n-vertex line-graphs that have been connected together. The
body has two antennae that result from adding an n-vertex line graph 
to one vertex on each side. 

    # the graph looks like
    #
    # (           top body               )   (       top antennae       )    
    #
    # o - o - o - ... n vertices total - o - o - ... n vertices total - 0
    # |   |   |   ...    |   |   |   |   |
    # o - o - o - ... n vertices total - o - o - ... n vertices total - 0
    #
    # (         bottom body              )   (     bottom antennae      )
    #
    # there are 4n vertices and 2(2n-1) + n edges 
    
    
Functions
---------
  * `roach_graph(n) -> A::MatrixNetwork`
  * `roach_graph(n, Val{true}) -> (A::MatrixNetwork, Matrix{Float64})` this also
    returns coordinates for the graph. 

Example
-------   
~~~~    
A = sparse_transpose(roach_graph(3, Val{true})) # get back the matrix 
L = spdiagm(vec(sum(A,2))) - A

#lams,vecs = eig(full(L))

~~~~

 
"""
function roach_graph end

roach_graph(n::Integer) = roach_graph(n::Integer, Val{false}) 

function roach_graph(n::Integer, ::Type{Val{false}}) 
    n >= 0 || throw(ArgumentError("n=$(n) must be larger than 0"))
    line1 = 1:(2n-1)
    line2 = 2:2n
    ei = [line1; line2; line1.+2n; line2.+2n; 1:n; 2n+1:2n+n]
    ej = [line2; line1; line2.+2n; line1.+2n; 2n+1:2n+n; 1:n]
    return _matrix_network_direct(sparse(ei,ej,1,4n,4n))
end

# get coordinates too
function roach_graph(n::Integer, ::Type{Val{true}}) 
    A = roach_graph(n, Val{false})
    xy = [-n:-1 -ones(n); 1:n -ones(n); -n:-1 ones(n); 1:n ones(n)]
    return A,xy
end    

"""
`lollipop_graph`
================

Generate a lollipop graph, which consists of a clique with a line tail, so
it looks like a lollipop.

Functions
---------
* `lollipop_graph(n)` generate the graph with an n-node tail and n-node clique
* `lollipop_graph(n,m)` generate the graph with an n-node tail and m-node clique
* `lollipop_graph(n,m,Val{true})` produce and return xy coordinates as well. 

Examples
--------

"""
function lollipop_graph end
lollipop_graph(n::Integer) = lollipop_graph(n, n)
lollipop_graph(n::Integer, ::Type{Val{false}}) = lollipop_graph(n, n)
lollipop_graph(n::Integer, ::Type{Val{true}}) = lollipop_graph(n, n, Val{true})
lollipop_graph(n::Integer, m::Integer) = lollipop_graph(n, m, Val{false})
function lollipop_graph(n::Integer, m::Integer, ::Type{Val{false}})
    n >= 0 || throw(ArgumentError("n=$(n) must be larger than 0"))
    m >= 0 || throw(ArgumentError("m=$(m) must be larger than 0"))    
    line1 = 1:n
    line2 = 2:n+1
    clique1 = map(x -> x[1], IterTools.subsets(n+1:n+m,2))
    clique2 = map(x -> x[2], IterTools.subsets(n+1:n+m,2))
    ei = [line1; line2; clique1; clique2]
    ej = [line2; line1; clique2; clique1]
    return _matrix_network_direct(sparse(ei,ej,1,n+m,n+m))
end
function lollipop_graph(n::Integer, m::Integer, ::Type{Val{true}})
    A = lollipop_graph(n,m, Val{false})
    xy = [-n:-1 zeros(n);  
        (-sqrt(m)*cos.(2*pi*(m:-1:1)/m).+(sqrt(m)+1)) sqrt(m)*sin.(2*pi*(m:-1:1)/m)]
    return A, xy
end


function rewire_graph(A::MatrixNetwork, k::Integer)
    if is_undirected(A)
        ei,ej = undirected_edges(A)
    else
        ei,ej = directed_edges(A)
    end
end

#=
function random_symmetric_edge(A::MatrixNetwork)
    ei,ej,ind1 = random_edge(A)
    ind2 = searchsortedfirst(@view A.ci[A.rp[ej]:A.rp[ej+1]-1], ei)
end
random_undirected_edge(A::MatrixNetwork)

function reverse_edge_index(A::MatrixNetwork, ei::Integer, ej::Integer)
    
end
=#


# TODO Add chung-lu for general floating point weights
# via union of ER graphs add 

"""
`forest_fire_graph`
===================

Create an instance of a forest fire graph. The forest fire
model consists of ...

Usage
-----
`A = forest_fire_graph(c, k, p)` returns a forest-fire sample. 
`A = forest_fire_graph(A0, k, p)` 
"""


"""
`partial_duplication`
=====================

A random graph model based off of the evolution of protein-protein interaction
networks. The method takes an undirected graph and runs a number of steps 
which randomly selects an existing vertex, duplicates the node, and keeps the
edges between its neighbor with a given probability. In the original work 
the authors prove that new vertices will tend to become isolated for 
p <= 0.567143. 

src: 
    Large-scale behavior of the partial duplication random graph
    Felix Hermann & Peter Pfaffelhuber
    https://arxiv.org/pdf/1408.0904.pdf

Input
-----
- 'A::MatrixNetwork{T}': seed matrix network 
- `steps::Int': The number of steps to run the procedure
- `p::Float64': the probability 

Output
------
- a new matrix network generated through the partial duplication procedure. 
""" 
function partial_duplication(A::MatrixNetwork{T},steps::Integer, p::Float64) where T
 
    is_undirected(A) || throw(ArgumentError("A must be undirected."))
    (p >= 0 && p <= 1) || throw(ArgumentError("new_edge_p must be a probability."))
    steps >= 0 || throw(ArgumentError("Must take a non-negative number of steps."))
    # let it steps equal 0 for testing purposes

    n,_ = size(A) # n will be updated


    #store A as an edge list so it's fast to sample
    A_edge_list = Array{Array{Tuple{Int,T},1},1}(undef,n+steps)
    for i = 1:n
        A_edge_list[i] = collect(zip(_get_row(A,i)...))
    end
    for i = n+1:n+steps
        A_edge_list[i] = Array{Tuple{Int,T},1}(undef,0)
    end

    for step in 1:steps

        dup_vertex = rand(1:n)
        for (neighbor,weight) in A_edge_list[dup_vertex]
            if rand() < p
                push!(A_edge_list[n+1],(neighbor,weight))
                push!(A_edge_list[neighbor],(n+1,weight))
            end
        end
        n += 1
    end


    #convert edge list back into a MatrixNetwork
    total_edges = 0
    for i=1:n
        total_edges += length(A_edge_list[i])
    end

    Is = Array{Int,1}(undef,total_edges)
    Js = Array{Int,1}(undef,total_edges)
    Vs = Array{T,1}(undef,total_edges)

    edge_idx = 1
    for i=1:n
        for (n_j,weight) in A_edge_list[i]
            Is[edge_idx] = i 
            Js[edge_idx] = n_j
            Vs[edge_idx] = weight
            edge_idx += 1
        end
    end

    #compress to csr 
    At = sparse(Js,Is,Vs,n,n)
    return MatrixNetwork(n,At.colptr,At.rowval,At.nzval)

end

"""
'_get_row'
==========
Helper function to extract out a row of a MatrixNetwork.

Output
------
- 'nz_indices'::Array{Int,1}: non-zero column indices.
- 'nz_weights'::Array{T,1}: non-zero weights.

"""
function _get_row(A::MatrixNetwork{T},i::Int) where T

   (i >= 1 && i <= size(A,1)) || throw(ArgumentError("i must be in {1,...,size(A,1)}"))
   return A.ci[A.rp[i]:A.rp[i+1]-1],A.vals[A.rp[i]:A.rp[i+1]-1]

end