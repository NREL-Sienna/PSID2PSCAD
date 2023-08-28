using Documenter

push!(LOAD_PATH,"../_pscad_libraries/")
push!(LOAD_PATH,"../_pscad_psid_conversion/")
push!(LOAD_PATH,"../..")


makedocs(
    sitename = "PSID2PSCAD",
    format = Documenter.HTML(),
 #   modules = [PSID2PSCAD]
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
#=deploydocs(
    repo = "<repository url>"
)=#
