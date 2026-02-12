# EventStudy.jl

This library can be used to run Event Studies as outlined in [(McKinlay, 1997)](https://www.jstor.org/stable/2729691#:~:text=Using%20financial%20market%20data%2C%20an,reflected%20immediately%20in%20security%20prices.).

It has the following advantages over existing solutions:
- Estimates normal returns using an arbitrary regression model
- Runs fast and reliable for large samples (10000 events and more), including the [(Kolari, 2020)](https://academic.oup.com/rfs/article-abstract/23/11/3996/1605665?redirectedFrom=fulltext) and [(Kolari, 2011)](https://www.sciencedirect.com/science/article/abs/pii/S0927539811000624) test statistics.
