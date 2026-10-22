---
title: Migrating my site to AWS CDN 
publishDate: 2026-10-22
modified: 2026-10-22
author: Iwan Ingman
description: 
  I recently migrated my personal site from a single-node Kubernetes cluster to AWS S3 and CloudFront. This post details the process, challenges, and results of the migration.
---

## Background
When I initially set this site up, I deployed it to my personal single-node Kubernetes cluster. This setup caused me no end of trouble, including issues with the reliability of deployment,
and absolutely no reproducability of the environment.

I've been thinking for a while about moving the site over to a CDN, as after all it is just a bunch of static files. It's been at the back of my mind for a while, but yesterday I was at the 
Serverless Days conference in Cardiff, which had a number of speakers from AWS. This was the impetus for me to finally make the move over to a much more enterprise-ready approach.

## Learning IaC
As I'm deploying this site to a cloud provider, I decided that if I was going to do it right, I needed to do it right. For this reason, I started looking at Terraform, which is yet another 
technology I've been meaning to sink my teeth into for quite some time.

I started off by making a simple architecture diagram based on an AWS blog article about hosting static sites on S3.
![Basic architecture diagram](/images/aws-static-hosting.svg)
This is hardly the best diagram I've ever made, but it should be pretty clear what I had in mind. Github actions builds the static files as before, but rather than building a docker container 
and redeploying to Kubernetes, it just uploads the files to an S3 bucket. Route 53 manages the DNS for the site, sending traffic to CloudFront, which serves the files from the S3 bucket.

## Security (oh no)
The most annoying part of the whole project was configuring the IAM policies for Terraform and for the deployment. I've configured the deployment's IAM policies from within terraform, but 
I had to set up a user in AWS IAM for Terraform to use when I was first applying the terraform config. It was pretty tedious to get all the policies right, and I stayed up until 1am this morning 
giving it all of the right permissions. On first run on my laptop I had to use an access key for the terraform user, but once it was working I can delete the keys and just have Github actions use 
OIDC.

One thing I almost forgot was to restrict access to the S3 bucket to only allow access from CloudFront.

## Bugs
The first problem I ran into was that I could only access the index page of the site, the rest were returning 403 Unauthorized errors. Turns out as Astro was putting each individual page into its own 
folder, so I had to reconfigure CloudFront to rewrite the URLs to the index.html in each folder. It was a bit of a pain but Copilot helped write the new CloudFront config, which would have been a massive 
hassle otherwise.

I also had to set up a rule to redirect from the root (apex) domain to the www subdomian, as I wanted to keep the www subdomain as the canonical domain for the site. This required me to reconfigure Route 53 and add another rule in CloudFront to redirect. Copilot pointed out that I was omitting any query parameters in the redirect, which could have been problematic as it would remove UTM data for analytics (though I don't even really look at the analytics in all honesty). 

## Deployment
Once I configured a role for Terraform to use with OIDC, I was able to get the deployment working from Github actions. It worked on the 3rd try, which is a personal best for new CI/CD pipelines!

## Results
Comparing pinging the site from my laptop to pinging another landing page that is still running on my Kubernetes node, the ping seems about the same.

New site:
```
ping -c 3 www.iwaningman.com
PING www.iwaningman.com (13.224.95.40) 56(84) bytes of data.
64 bytes from server-13-224-95-40.lhr95.r.cloudfront.net (13.224.95.40): icmp_seq=1 ttl=246 time=10.6 ms
64 bytes from server-13-224-95-40.lhr95.r.cloudfront.net (13.224.95.40): icmp_seq=2 ttl=246 time=10.6 ms
64 bytes from server-13-224-95-40.lhr95.r.cloudfront.net (13.224.95.40): icmp_seq=3 ttl=246 time=12.6 ms

--- www.iwaningman.com ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2004ms
rtt min/avg/max/mdev = 10.606/11.259/12.560/0.919 ms
```

Old site:
```
ping -c 3 www.iwani.dev
PING www.iwani.dev (104.21.56.90) 56(84) bytes of data.
64 bytes from 104.21.56.90: icmp_seq=1 ttl=53 time=9.83 ms
64 bytes from 104.21.56.90: icmp_seq=2 ttl=53 time=9.73 ms
64 bytes from 104.21.56.90: icmp_seq=3 ttl=53 time=12.8 ms

--- www.iwani.dev ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2004ms
rtt min/avg/max/mdev = 9.732/10.791/12.807/1.426 ms
```

Honestly I was expecting it to be a lot faster, but at least it isn't a regression. I think the real benefits lie in 1. The reliability of the site; and 2. The ability to handle way more traffic.
It will probably also provide more consistent performance in other parts of the world where my Kubernetes node is not located. I will have to do some more testing to see if this is the case, but I think it will be.

Also, my comments server is still running on Kubernetes, but I'm still not sure whether I should even have that running anyway, but I'm still thinking about that.

## Conclusion
This was a pretty fun short project for me, and it's a good break from my regular boring University work. I've made my site a lot more reliable, and in the process improved my knowledge of AWS, Terraform, and Github actions. I think the next step is to look at how I can make the deployment even more reliable, and maybe even add some better monitoring to the site.

