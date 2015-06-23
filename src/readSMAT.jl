function readSMAT(filename)
    (rows,header) = readdlm(filename;header=true)
    A = sparse(
               convert(Array{Int64,1},rows[:,1]), 
               convert(Array{Int64,1},rows[:,2]), 
               rows[:,3],
               int(header[1]), 
               int(header[2])
               )
end