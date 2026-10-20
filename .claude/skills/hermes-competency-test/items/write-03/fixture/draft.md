## Getting access to the kiln build cluster

As many of you will already know, the kiln build cluster is the shared pool of build machines that the platform team set up back in 2023 in order to take some of the load off everyone's laptops and to make our CI builds more consistent. Over time it has grown quite a bit, and it is now used by most of the engineering teams on a fairly regular basis, which is great, but it does mean that we have had to put a slightly more formal process in place around who can get access to it and how that access is managed going forward.

If you would like to get access to kiln, the first thing that you will need to do is open a ticket in the INFRA queue on the ticket tracker at https://tickets.example.com/infra. Please do not send direct messages to individual members of the platform team asking for access, because those requests tend to get lost, and it also makes it very difficult for us to keep any kind of record of who has been given access and when. In the ticket, it is helpful if you can include your team name and a short description of what you are planning to build on the cluster.

Once the ticket has been submitted, someone from the platform team will review it, and in most cases you can expect your request to be approved within 2 business days. It may occasionally be a little faster than that, and during very busy periods it might take slightly longer, but 2 business days is what we aim for in general.

As part of the ticket, you will also need to attach the public half of an SSH key. It is important to note that we now require all keys to be ed25519 keys. In the past we did accept RSA keys, but this is no longer the case, and any ticket with an RSA key attached will unfortunately have to be sent back to you so that you can generate a new key and attach it.

Finally, please be aware that access to kiln is not permanent. Access automatically expires after 90 days, at which point you will need to renew it by commenting on your original ticket. You will normally receive a reminder email about a week before your access is due to expire, so that there is plenty of time to renew it without losing access in the meantime.
