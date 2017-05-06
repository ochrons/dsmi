From mwc!utrix!mwcbbs!trxhome!trixter@uunet.UU.NET Tue Apr 26 11:27:48 1994
Received: from relay1.UU.NET (relay1.UU.NET [192.48.96.5]) by clinet.fi (8.6.4/8.6.4) with SMTP id LAA02589 for <jlahd@clinet.fi>; Tue, 26 Apr 1994 11:27:43 +0300
Received: from uucp3.uu.net by relay1.UU.NET with SMTP 
	(5.61/UUNET-internet-primary) id AAwngr28492; Tue, 26 Apr 94 04:29:22 -0400
Received: from mwc.UUCP by uucp3.uu.net with UUCP/RMAIL
        ; Tue, 26 Apr 1994 04:29:23 -0400
Received: by mwc.com (smail2.5.3-coh) id AA10624; 26 Apr 94 05:51:32 GMT (Tue)
Received: by utrix.mwc.com (smail2.5.3-coh) id AA00814; 26 Apr 94 06:42:02 GMT (Tue)
Received: by mwcbbs.UUCP (smail2.5.3-coh) id AA01295; 26 Apr 94 05:24:24 GMT (Tue)
Received: by trxhome.mwc.com (smail2.5.3-coh) id AA00079; 26 Apr 94 00:25:05 CST (Tue)
Subject: Uh oh
To: jussi@trxhome.mwc.com
From: Trixter / Independent <trixter@trxhome.mwc.com>
X-Mailer: ELM [version 2.3 PL11]
Message-Id: <9404260025.AA00077@trxhome.mwc.com>
Date: 26 Apr 94 00:25:05 CST (Tue)
Status: RO

Unfortunately, I'm in need of your assistance again.  Could you help me
with something?  (But don't miss any parties for it--in fact, if there's
a party you should be at or getting ready for, I order you do turn off
the computer right now.  :-)

Remember when you told me how to grab the current sample byte from EMS
memory (fast) instead of GUS memory (slow)?  Here's what you said to me:

------------quote begin------------------------

> Oh!  Speaking of updates, I have a perplexing problem.  Beta-testers of
> Chromatiks really want an oscilliscope for the GUS, so I calculate it
> myself with GUSPeek().  The problem is, GUSPeek is SLOW because it goes
> through the port.  Is there any way I can use the info from
> CDIGetSample/CDIGetSamplePosition (or whatever, can't remember right
> now) but use it to get the data from the sample loaded in EMS?  

Let's see...
Yes. It can be done, though it's not too easy.
First, you have to get the track information with ampGetTrackData. In the
track data structure, there is the instrument number. With it, you can get
the pointer to the sample data from the module structure. Assuming the
currently played module to be variable module:PModule, and the variable 
where you got the track data to be td:PTrackData,
module^.instruments^[td^.instrument].sample
gives you the pointer to the sample. With cdiGetSamplePosition you can get
the position (as before), and then just read the data.
EXCEPT if the sample is in EMS. At first, you know this from the pointer.
If the segment part of the pointer is -1 ($ffff), the sample is virtual.
You can get the sample data by calling emsLock(<offset_of_sample_pointer>,
0,64000). It returns you a pointer (to the EMS page frame) where you can
read the sample.

-----------------end quote----------------------------------

Well, I came up with a simple function to test this; it reads all the
tracks, and then calculates a "mixed" byte (I know this is incredibly
non-optimized for an oscilliscope, I'm just keeping it simple until it
works).  Here's what I wrote:

function gusmixbyte:byte;
var
  offset:word;
  mixed:longint;
  loop:byte;
  td:Ptrackdata;
  smp:psampleinfo;
  samplevalue:^byte;

begin
  mixed:=0;
  for loop:=0 to _curmodule.channelcount-1 do begin
    offset:=gusGetPosition(loop);
    td:=ampgettrackdata(loop);
    smp:=_curmodule.instruments^[td^.instrument].sample;
    if seg(smp^.sample)=$ffff
      then samplevalue:=emslock(ofs(smp),0,64000)
      else samplevalue:=smp^.sample;
    inc(longint(samplevalue),offset);
    inc(mixed,samplevalue^ xor $80);
  end;
  mixed:=mixed div longint(_curmodule.channelcount);
  gusmixbyte:=mixed;
end;

It looks good, but it outputs quasi-garbage (meaning that the garbage
looks vaguely like sample data, but after a while you realize it's just
memory noise).

Did I miss something?
-- 
Jim Leonard, trixter@trxhome.mwc.com
Creator/Coder/Maintainer of Chromatiks.  (Ask me about it!)
Send all music/graphics submissions to chromatiks@trxhome.mwc.com
GO d p c+++ l- u+@ e+ m* s++ n+(--) h--- f g++ w+(-) t++@ r y+ 
You know when you've been playing DOOM too much...
...when you wish you had a chainsaw, just in case.

