#!/usr/bin/perl

use Class::Struct;
use XML::Twig;
use IO::Socket;

my $path="/ngnx/smsc";
my $own_smsc_gt="4012555770000058";
my $own_smsc_route="gt";
my $own_smsc_ssn="8";
my $own_hlr_ssn="6";

struct (Mtp => {
	remotePC => '$',
	localPC => '$',
	sls => '$',
});
struct (Sccp => {
	a_ssn => '$',
	a_gt => '$',
	a_route => '$',
	b_ssn => '$',
	b_gt => '$',
	b_route => '$',
});
struct (Component => {
	remoteCID => '$',
	type => '$',
	opcode => '$',
	status => '$',
});
struct (Tcap => {
	reqType => '$',
	remoteID => '$',
	localID => '$',
	dialogType => '$',
	app => '$',
	component => 'Component',
});
struct (payloadSRIforSM => {
	msisdn => '$',
	smsc => '$',
	imsi => '$',
	vlr => '$',
});
struct (sm_RP_UI => {
	tp_mti => '$',
	tp_mms => '$',
	tp_sri => '$',
	tp_udhi => '$',
	tp_rp => '$',
	typeOfAddress => '$',
	tp_oa => '$',
	tp_pid => '$',
	tp_dcs => '$',
	tp_scts => '$',
	tp_udl => '$',
	tp_ud => '$',
	tp_udh_len => '$',
	tp_ie_len => '$',
	tp_ie_id => '$',
	tp_ie_messid => '$',
	tp_ie_parts => '$',
	tp_ie_partnum => '$',
	sms => '$',
	res => '$',
});
struct (payloadMTSMS => {
	sm_rp_da => '$',
	sm_rp_oa => '$',
	sm_rp_ui => 'sm_RP_UI',
});
struct Message => 
[
	mtp => 'Mtp',
	sccp => 'Sccp',
	tcap => 'Tcap',
	pSRI => 'payloadSRIforSM',
	pMT => 'payloadMTSMS',
];

my @LOCALID_POOL=("0");
my @IMSI_POOL=("226059999000000");


my($msc, $hlr)=&initApp();
my $pid=fork();
if (not defined $pid) {
	print "Resource not available \n";
	exit(-1);
} elsif ($pid == 0) {
	for (;;){
		$hlr->recv(my $txt, 4096);
		my $send=&appSMS($txt);
		if (defined $send) {
			$hlr->send($send,40096);
		}
	}
} else {
	for (;;) {
		$msc->recv(my $txt, 4096);
		my $send=&appSMS($txt);
		if (defined $send) {
			$msc->send($send,40096);
		}
	}
	waitpid($pid,0);
}

#------------------------ sub-routine ----------------------------------
sub initConMsc {
	my $msc = new IO::Socket::INET (
	        	PeerAddr => '222.165.188.198',
		        PeerPort => '5557',
			Proto => 'tcp',
	) or die "Could not create socket for MSC: $!\n";
	return $msc
}
sub initConHlr {
	my $hlr = new IO::Socket::INET (
	        PeerAddr => '222.165.188.198',
	        PeerPort => '5557',
	        Proto => 'tcp',
	) or die "Could not create socket for HLR: $!\n";
	return $hlr

}
sub initApp {
	open ("f","$path/template/smsc.xml") or die "Init file not found\n";
		my @file=<f>;
	close ("f");
	my $hlr=&initConHlr();
	my $msc=&initConMsc();
	print $hlr @file;
	$hlr->recv(my $hlr_recv,4096);
	if ($hlr_recv!~/state>active/){
	        exit;
	}
	print $msc @file;
	$msc->recv(my $msc_recv,4096);
	if ($msc_recv!~/state>active/){
	        exit;
	}
	print "SMS-GW is ready\n";
	return ($msc,$hlr);
}

sub initMessage {
	my $message = Message->new(
		mtp=>Mtp->new(), 
		sccp=>Sccp->new(), 
		tcap=>Tcap->new(
			component=>Component->new(),
		),
		pSRI=>payloadSRIforSM->new(),
		pMT=>payloadMTSMS->new(
			sm_rp_ui=>sm_RP_UI->new(),
		),
	);
	return $message;
	
}
sub printMessage {
	my $mes = shift;
	print "message.mtp.remotePC = ", $mes->mtp->remotePC, "\n";
	print "message.mtp.localPC = ", $mes->mtp->localPC, "\n";
	print "message.mtp.sls = ", $mes->mtp->sls, "\n";
	print "message.sccp.a_ssn = ", $mes->sccp->a_ssn, "\n";
	print "message.sccp.a_route = ", $mes->sccp->a_route, "\n";
	print "message.sccp.a_gt = ", $mes->sccp->a_gt, "\n";
	print "message.sccp.b_ssn = ", $mes->sccp->b_ssn, "\n";
	print "message.sccp.b_route = ", $mes->sccp->b_route, "\n";
	print "message.sccp.b_gt = ", $mes->sccp->b_gt, "\n";
	print "message.tcap.reqTyep = ", $mes->tcap->reqType, "\n";
	print "message.tcap.remoteID = ", $mes->tcap->remoteID, "\n";
	print "message.tcap.localID = ", $mes->tcap->localID, "\n";
	print "message.tcap.dialogType = ", $mes->tcap->dialogType, "\n";
	print "message.tcap.application = ", $mes->tcap->app, "\n";
	print "message.tcap.component.remoteCID = ", $mes->tcap->component->remoteCID, "\n";
	print "message.tcap.component.type = ", $mes->tcap->component->type, "\n";
	print "message.tcap.component.opcode = ", $mes->tcap->component->opcode, "\n";
	print "message.tcap.component.status = ", $mes->tcap->component->status, "\n";
	if ($mes->tcap->component->opcode=~/sendRoutingInfoForSM/){
		print "message.tcap.payload.SriforSM-Req.msisdn = ", $mes->pSRI->msisdn, "\n";
		print "message.tcap.payload.SriforSM-Req.smsc = ", $mes->pSRI->smsc, "\n";
		print "message.tcap.payload.SriforSM-Res.imsi = ", $mes->pSRI->imsi, "\n";
		print "message.tcap.payload.SriforSM-Res.vlr = ", $mes->pSRI->vlr, "\n";
	}
	if ($mes->tcap->component->opcode=~/mt-forwardSM/) {
		print "message.tcap.payload.MT-SMS.sm-RP-DA.imsi = ", $mes->pMT->sm_rp_da, "\n";
		print "message.tcap.payload.MT-SMS.sm-RP-OA.serviceCentreAddressOA = ", $mes->pMT->sm_rp_oa, "\n";
		print "message.tcap.payload.MT-SMS.sm-RP-UI.TP-MTI = ", $mes->pMT->sm_rp_ui->tp_mti, "\n";
		print "message.tcap.payload.MT-SMS.sm-RP-UI.TP-MMS = ", $mes->pMT->sm_rp_ui->tp_mms, "\n";
		print "message.tcap.payload.MT-SMS.sm-RP-UI.TP-SRI = ", $mes->pMT->sm_rp_ui->tp_sri, "\n";
		print "message.tcap.payload.MT-SMS.sm-RP-UI.TP-UDHI = ", $mes->pMT->sm_rp_ui->tp_udhi, "\n";
		print "message.tcap.payload.MT-SMS.sm-RP-UI.TP-RP = ", $mes->pMT->sm_rp_ui->tp_rp, "\n";
		print "message.tcap.payload.MT-SMS.sm-RP-UI.typeOfAddress = ", $mes->pMT->sm_rp_ui->typeOfAddress, "\n";
		print "message.tcap.payload.MT-SMS.sm-RP-UI.TP-OA = ", $mes->pMT->sm_rp_ui->tp_oa, "\n";
		print "message.tcap.payload.MT-SMS.sm-RP-UI.TP-PID = ", $mes->pMT->sm_rp_ui->tp_pid, "\n";
		print "message.tcap.payload.MT-SMS.sm-RP-UI.TP-DCS = ", $mes->pMT->sm_rp_ui->tp_dcs, "\n";
		print "message.tcap.payload.MT-SMS.sm-RP-UI.TP-SCTS = ", $mes->pMT->sm_rp_ui->tp_scts, "\n";
		print "message.tcap.payload.MT-SMS.sm-RP-UI.TP-UDL = ", $mes->pMT->sm_rp_ui->tp_udl, "\n";
		print "message.tcap.payload.MT-SMS.sm-RP-UI.TP-UD = ", $mes->pMT->sm_rp_ui->tp_ud, "\n";
		if ($mes->pMT->sm_rp_ui->tp_udhi != 0) {
			print "message.tcap.payload.MT-SMS.sm-RP-UI.TP-UD.user_header_len = ", $mes->pMT->sm_rp_ui->tp_udh_len, "\n";
			print "message.tcap.payload.MT-SMS.sm-RP-UI.TP_UD.information_element = ", $mes->pMT->sm_rp_ui->tp_ie_id, "\n";
			print "message.tcap.payload.MT-SMS.sm-RP-UI.TP-UD.information_element_len = ", $mes->pMT->sm_rp_ui->tp_ie_len, "\n";
			print "message.tcap.payload.MT-SMS.sm-RP-UI.TP-UD.message_id = ", $mes->pMT->sm_rp_ui->tp_ie_messid, "\n";
			print "message.tcap.payload.MT-SMS.sm-RP-UI.TP-UD.message.parts = ", $mes->pMT->sm_rp_ui->tp_ie_parts, "\n";
			print "message.tcap.payload.MT-SMS.sm-RP-UI.TP-UD.partnum = ", $mes->pMT->sm_rp_ui->tp_ie_partnum, "\n";
		}
		print "message.tcap.payload.MT-SMS.sm-RP-UI.SMS = ", $mes->pMT->sm_rp_ui->sms, "\n";
		print "message.tcap.payload.MT-SMS.sm-RP-UI.Response = ", $mes->pMT->sm_rp_ui->res, "\n";

	}
	print "\n";
}
sub deallocImsi {
	my $imsi=shift;
	my $len=@IMSI_POOL;
	my $min=226059999000000;
	my $max=226059999999999;
	@IMSI_POOL = sort {$a <=> $b} @IMSI_POOL;
	if ($imsi-$min-1<=0) {
		@IMSI_POOL=("226059999000000");
	} else {
		$IMSI_POOL[$imsi-$min-1]=$max;
		@IMSI_POOL = sort {$a <=> $b} @IMSI_POOL;
		pop(@IMSI_POOL);
	}
}
sub allocImsi {
	my $imsi = "";
	@IMSI_POOL = sort {$a <=> $b} @IMSI_POOL;
	my $min=226059999000000;
	my $max=226059999999999;
	my $len = $max-$min-1;
	for ($i=0; $i<$len; $i++){
		if ($IMSI_POOL[$i]!=$i+$min){
			$imsi=$i+$min;
			push(@IMSI_POOL,$imsi);	
			return $imsi;
		}
	}
	return "-1";
}
sub allocLocalID {
	my $mes = shift;
	my $len = hex('FFFFFFFF');
	@LOCALID_POOL = sort {$a <=> $b} @LOCALID_POOL;
	for ($i=0; $i<$len; $i++){
		if ($LOCALID_POOL[$i]!=$i){
			push(@LOCALID_POOL,$i);	
			$hex = sprintf("%08x",$i);
			$mes->tcap->localID($hex);
			return $mes;
		}
	}
	return "-1";
}
sub rol {
	# Usage: &rol(number, n)
	my $number = shift;
	my $bits2rotate = shift;
	for (1..$bits2rotate) {
		$number = $number << 1;
		my $rmb = 0;
		if ($number > 255) {
			my $rmb = 1;
			$number -= 255;
		}
		$number += $rmb;
	}
	return $number;
}
sub decodeTP_UD {
	my @UD=@_;
	my @DEFAULT_CHARSET=("@","","\$","","","","","","","", 		  #0-9
			"\n","","","\r","","","","_","","", 		  #10-19
			"","","","","","","","","","",   		  #20-29
			" ", "", " ", "!", "\"", "#", "", "%", "&", "\'", #30-39
			"(", ")", "*", "+", ",", "-", ".", "/", "0", "1", #40-49
			"2", "3", "4", "5", "6", "7", "8", "9", ":", ";", #50-59
			"<", "=", ">", "?", "", "A", "B", "C", "D", "E",  #60-69
			"F", "G", "H", "I", "J", "K", "L", "M", "N", "O", #70-79
			"P", "Q", "R", "S", "T", "U", "V", "W", "X", "Z", #80-89
			"Z", "", "", "", "", "", " ", "a", "b", "c", 	  #90-99
			"d", "e", "f", "g", "h", "i", "j", "k", "l", "m", #100-109
			"n", "o", "p", "q", "r", "s", "t", "u", "v", "w", #110-119
			"x", "y", "z", "", "", "", "", "");		  #120-127
	my $len=@UD;
	print "LEN = $len; UD =".@UD."\n";
	my $str="";
	my $j=0;
	my $st=0;
	for (my $i=0; $i<$len; $i++){
		$val=hex($UD[$i]);
		if ($i<7) {
			$j=$i;
		} else {
			$str .= $DEFAULT_CHARSET[$r6];
			$j=$i-$st;
		}
		if ($j==0) {
			$r0 = $val & 128;
			$r0 = $r0>> 7;
			$val = $val & 127;
			$str .= $DEFAULT_CHARSET[$val];
		}
		if ($j==1) {
			$r1 = $val & 192;
			$r1 = $r1 >> 6;
			$val = $val & 63;
			$val = $val << 1;
			$val = $val + $r0;
			$str .= $DEFAULT_CHARSET[$val];
		}
		if ($j==2) {
			$r2 = $val & 224;
			$r2 = $r2 >> 5;
			$val = $val & 31;
			$val = $val << 2;
			$val = $val + $r1;
			$str .= $DEFAULT_CHARSET[$val];
		}
		if ($j==3) {
			$r3 = $val & 240;
			$r3 = $r3 >> 4;
			$val = $val & 15;
			$val = $val << 3;
			$val = $val + $r2;
			$str .= $DEFAULT_CHARSET[$val];
		}
		if ($j==4) {
			$r4 = $val & 248;
			$r4 = $r4 >> 3;
			$val = $val & 7;
			$val = $val << 4;
			$val = $val + $r3;
			$str .= $DEFAULT_CHARSET[$val];
		}
		if ($j==5) {
			$r5 = $val & 252;
			$r5 = $r5 >> 2;
			$val = $val & 3;
			$val = $val << 5;
			$val = $val + $r4;
			$str .= $DEFAULT_CHARSET[$val];
		}
		if ($j==6) {
			$r6 = $val & 254;
			$r6 = $r6 >> 1;
			$val = $val & 1;
			$val = $val << 6;
			$val = $val + $r5;
			$str .= $DEFAULT_CHARSET[$val];
			#$str .= $DEFAULT_CHARSET[$r6];
			$st+=7;
		}
	}
	print "decode STR = $str\n";
	return $str;
}
sub decodeSM_RP_UI {
	my @SM_RP_UI=split(/ /,$_[0]);
	my$tp_mti = hex($SM_RP_UI[0]) & hex("03");
	my $tp_mms = hex($SM_RP_UI[0]) & hex("04");
	if ($tp_mms == 4) {$tp_mms=1};
	my $tp_sri = hex($SM_RP_UI[0]) & hex("20");
	if ($tp_sri == 32) {$tp_sri=1};
	my $tp_udhi = hex($SM_RP_UI[0]) & hex("40");
	if ($tp_udhi == 64) {$tp_udhi=1};
	my $tp_rp = hex($SM_RP_UI[0]) & hex("80");
	if ($tp_rp == 128) {$tp_rp=1};
	my $len_tp_oa = hex($SM_RP_UI[1])/2;
	my $type_of_address = $SM_RP_UI[2];
	my $tp_oa="";
	for (my $i=0; $i<$len_tp_oa; $i++) {
		my $left_result = &rol(hex($SM_RP_UI[$i+3]), 4);
		if ($SM_RP_UI[$i+3]=~/f/) {
			my $out = pack "c", $left_result;
			$tp_oa .= unpack "H1", $out;
		} else {
			my $out = pack "c", $left_result;
			$tp_oa .= unpack "H2", $out;
		}

	}
	my $offset = 3+($len_tp_oa+0.5);
	$tp_pid = hex($SM_RP_UI[$offset]);
	$tp_dcs = hex($SM_RP_UI[$offset+1]);
	my $tp_scts = "";
	for ($i=0; $i<7; $i++){
		$tp_scts .= $SM_RP_UI[$offset+2+$i];
	}
	$offset = $offset + 2 + $i;
	my $tp_udl = hex($SM_RP_UI[$offset]);
	my $dec_tp_ud="";
	my @TP_UD=();
	my $tp_ud="";
	my $len=@SM_RP_UI;
	for ($i=$offset+1; $i<$len; $i++){
		push(@TP_UD,$SM_RP_UI[$i]);
		$tp_ud.=$SM_RP_UI[$i];
	}
	my $tp_udh_len=0;
	my $tp_ie_id=0;
	my $tp_ie_len=0;
	my $tp_ie_messid=0;
	my $tp_ie_parts=0;
	my $tp_ie_partnum=0;
	if ($tp_udhi == 0) {
		if ($tp_dcs == 0) {
			$dec_tp_ud=&decodeTP_UD(@TP_UD);
		}
	}  else {
		$tp_udh_len = hex($TP_UD[0]);	
		$tp_ie_id = hex($TP_UD[1]);	
		if ($tp_ie_id == 0) {
			$tp_ie_len=hex($TP_UD[2]);
			$tp_ie_messid=hex($TP_UD[3]);
			$tp_ie_parts=hex($TP_UD[4]);
			$tp_ie_partnum=hex($TP_UD[5]);
			$dec_tp_ud="";
			my $len_tp_ud=@TP_UD;
			my @DEC_TP_UD=();
			for ($i=$tp_udh_len+1; $i<$len_tp_ud; $i++) {
				if ($i==$tp_udh_len+1) {
					if ($tp_dcs == 0) {
						my $tmp=hex($TP_UD[$i])>>1;
						$tmp = sprintf("%02x",$tmp);
						push (my @TMP,$tmp);
						$dec_tp_ud.=&decodeTP_UD(@TMP);
					}
				} else {
					push(@DEC_TP_UD,$TP_UD[$i]);
				}
			}
			if ($tp_dcs == 0) {
				$dec_tp_ud.=&decodeTP_UD(@DEC_TP_UD);
			}
		}
	}
	return ($tp_mti, $tp_mms, $tp_sri, $tp_udhi, $tp_rp, $type_of_address, $tp_oa, $tp_pid, $tp_dcs, $tp_scts, $tp_udl, $tp_ud, $tp_udh_len, $tp_ie_len, $tp_ie_id, $tp_ie_messid, $tp_ie_parts, $tp_ie_partnum ,$dec_tp_ud);
}
sub recvXML {
	my $text = shift;
	my $mes = &initMessage();
	my $xml=XML::Twig->new(
		pretty_print => 'indented'
	);
	my $root=$xml->root;
	$xml->parse($text);
	#mtp
	my $mtp = $xml->first_elt('mtp');
        my $localpc=$mtp->first_child_text('LocalPC');
        my $remotepc=$mtp->first_child_text('RemotePC');
        my $sls=$mtp->first_child_text('sls');
	$mes->mtp->remotePC($remotepc);
	$mes->mtp->localPC($localpc);
	$mes->mtp->sls($sls);
	#sccp
        my $sccp=$xml->first_elt('CalledPartyAddress');
        my $b_ssn=$sccp->field('ssn');
        my $b_route=$sccp->field('route');
        my $b_gt=$sccp->field('gt');
        $sccp=$xml->first_elt('CallingPartyAddress');
        my $a_ssn=$sccp->field('ssn');
        my $a_route=$sccp->field('route');
        my $a_gt=$sccp->field('gt');	
	$mes->sccp->a_ssn($a_ssn);
	$mes->sccp->a_route($a_route);
	$mes->sccp->a_gt($a_gt);
	$mes->sccp->b_ssn($b_ssn);
	$mes->sccp->b_route($b_route);
	$mes->sccp->b_gt($b_gt);
	#tcap
        my $tcap=$xml->first_elt('tcap');
        my $tcapID=$tcap->field('remoteTID');
	$tcapID=~s/ //gc;
	$mes->tcap->remoteID($tcapID);
        my $l=$xml->first_elt('localTID');
	if (defined($l)) {
	        my $localID=$tcap->field('localTID');
		$localID=~s/ //gc;
		$mes->tcap->localID($localID);
	} else {
		$mes->tcap->localID('false');
	}
        my $req_type=$tcap->field('request-type');
        my $dialog=$xml->first_elt('dialog');
	if (defined($dialog)) {
		my $dialog_type=$dialog->att('type');
		$mes->tcap->dialogType($dialog_type);
	} else {
		$mes->tcap->dialogType('false');
	}
	$mes->tcap->reqType($req_type);
	my $app=$xml->first_elt('application');
	if (defined($app)) {
		my $app=$xml->first_elt('m');
		my $app_name=$app->field('application');
		$mes->tcap->app($app_name);
	} else {
		$mes->tcap->app('false');
	}
	my $comp=$xml->first_elt('component');
	if ($comp) {
		my $opcode=$comp->att('operationCode');
		my $remoteCID=$comp->att('remoteCID');
		my $type=$comp->att('type');
		$mes->tcap->component->status('true');
		$mes->tcap->component->remoteCID($remoteCID);
		$mes->tcap->component->type($type);
		$mes->tcap->component->opcode($opcode);
	} else {
		$mes->tcap->component->status('false');
		return $mes;
	}
	#payload
	if ($mes->tcap->component->opcode=~/sendRoutingInfoForSM/ && $mes->tcap->reqType=~/Begin/){
	
		my $msisdn=$comp->field('msisdn');
        	my $smsc=$comp->field('serviceCentreAddress');
		$mes->pSRI->msisdn($msisdn);
		$mes->pSRI->smsc($smsc);
	}
	if ($mes->tcap->component->opcode=~/mt-forwardSM/ && ($mes->tcap->reqType=~/Begin/ || $mes->tcap->reqType=~/Continue/) ) {
		my $tmp=$xml->first_elt('sm-RP-DA');
		my $imsi=$tmp->field('imsi');
		$tmp=$xml->first_elt('sm-RP-OA');
		my $smsc=$tmp->field('serviceCentreAddressOA');
		$tmp=$xml->first_elt('component');
		my $smrpui=$tmp->field('sm-RP-UI');
		$mes->pMT->sm_rp_da($imsi);
		$mes->pMT->sm_rp_oa($smsc);
		my ($tp_mti, $tp_mms, $tp_sri, $tp_udhi, $tp_rp, $type_of_address, $tp_oa, $tp_pid, $tp_dcs, $tp_scts, $tp_udl, $tp_ud, $tp_udh_len, $tp_ie_len, $tp_ie_id, $tp_ie_messid, $tp_ie_parts, $tp_ie_partnum, $dec_tp_ud) = &decodeSM_RP_UI($smrpui);
		$mes->pMT->sm_rp_ui->tp_mti($tp_mti);
		$mes->pMT->sm_rp_ui->tp_mms($tp_mms);
		$mes->pMT->sm_rp_ui->tp_sri($tp_sri);
		$mes->pMT->sm_rp_ui->tp_udhi($tp_udhi);
		$mes->pMT->sm_rp_ui->tp_rp($tp_rp);
		$mes->pMT->sm_rp_ui->typeOfAddress($type_of_address);
		$mes->pMT->sm_rp_ui->tp_oa($tp_oa);
		$mes->pMT->sm_rp_ui->tp_pid($tp_pid);
		$mes->pMT->sm_rp_ui->tp_dcs($tp_dcs);
		$mes->pMT->sm_rp_ui->tp_scts($tp_scts);
		$mes->pMT->sm_rp_ui->tp_udl($tp_udl);
		$mes->pMT->sm_rp_ui->tp_ud($tp_ud);
		$mes->pMT->sm_rp_ui->tp_udh_len($tp_udh_len);
		$mes->pMT->sm_rp_ui->tp_ie_len($tp_ie_len);
		$mes->pMT->sm_rp_ui->tp_ie_id($tp_ie_id);
		$mes->pMT->sm_rp_ui->tp_ie_messid($tp_ie_messid);
		$mes->pMT->sm_rp_ui->tp_ie_parts($tp_ie_parts);
		$mes->pMT->sm_rp_ui->tp_ie_partnum($tp_ie_partnum);
		$mes->pMT->sm_rp_ui->sms($dec_tp_ud);
	}
	return $mes;
}
sub getXMLTemplate {
	my $xml="";
	open ("f","$path/template/template.xml") or die "File \'$path/template/template.xml\' not found\n";
	        while (<f>){
	                $xml.=$_;
	        }
	close ("f");
	return $xml;
}
sub formatTcapID {
	my $str=shift;
	my $tmp1=substr($str,0,2);
	my $tmp2=substr($str,2,2);
	my $tmp3=substr($str,4,2);
	my $tmp4=substr($str,6,2);
	my $tcapID=$tmp1." ".$tmp2." ".$tmp3." ".$tmp4;
	return $tcapID;
}
sub sendXML {
	my $mes = shift;
	my $str = &getXMLTemplate();
	my $xml=XML::Twig->new(
                pretty_print => 'indented'
        );
	$xml->parse($str);
	my $root=$xml->root;
	#mtp
	my $mtp=$xml->first_elt('LocalPC');
	$mtp->set_text($mes->mtp->localPC);
	$mtp=$xml->first_elt('RemotePC');
	$mtp->set_text($mes->mtp->remotePC);
	$mtp=$xml->first_elt('sls');
	$mtp->set_text($mes->mtp->sls);
	#sccp
        my $sccp=$xml->first_elt('CalledPartyAddress');
        $xml->set_root($sccp);
        my $tmp=$xml->first_elt('ssn');
        $tmp->set_text($mes->sccp->b_ssn);
        $tmp=$xml->first_elt('gt');
        $tmp->set_text($mes->sccp->b_gt);
        $tmp=$xml->first_elt('route');
        $tmp->set_text($mes->sccp->b_route);
        $xml->set_root($root);
        my $sccp=$xml->first_elt('CallingPartyAddress');
        $xml->set_root($sccp);
        my $tmp=$xml->first_elt('ssn');
        $tmp->set_text($mes->sccp->a_ssn);
        $tmp=$xml->first_elt('gt');
        $tmp->set_text($mes->sccp->a_gt);
        $tmp=$xml->first_elt('route');
        $tmp->set_text($mes->sccp->a_route);
        $xml->set_root($root);
	#tcap
	my $tcap=$xml->first_elt('tcap');
	$xml->set_root($tcap);
	my $tmp=$xml->first_elt('request-type');
	$tmp->set_text($mes->tcap->reqType);
	my $tmp=$xml->first_elt('localTID');
	my $str=&formatTcapID($mes->tcap->localID);
	$tmp->set_text($str);
	my $tmp=$xml->first_elt('remoteTID');
	my $str=&formatTcapID($mes->tcap->remoteID);
	$tmp->set_text($str);
	if ($mes->tcap->dialogType !~ /false/){
		$tcap->insert_new_elt(
				dialog => {
					type => $mes->tcap->dialogType,
					version => '1',
				},
		);
	}
	$xml->set_root($root);
	if ($mes->tcap->app !~/false/){
		my $m = $xml->first_elt('m');
		$m->insert_new_elt(
			application => ''
		);
		my $a=$xml->first_elt('application');
		$a->set_text($mes->tcap->app);
	}
	if ($mes->tcap->component->status=~/true/) {
		my $m=$xml->first_elt('m');
		$m->insert_new_elt(
			component => {
				remoteCID => $mes->tcap->component->remoteCID,
				type => $mes->tcap->component->type,
				operationCode => $mes->tcap->component->opcode,
			},
		);
		my $comp=$xml->first_elt('component');
		if ($mes->tcap->component->opcode=~/sendRoutingInfoForSM/ && $mes->tcap->component->type=~/ResultLast/){
			$comp->insert_new_elt(
				imsi => $mes->pSRI->imsi,
			);
			$comp->insert_new_elt(
				locationInfoWithLMSI => '',
			);
			$comp=$xml->first_elt('locationInfoWithLMSI');
			my $net="networkNode-Number";
			$comp->insert_new_elt(
				$net => {
					nature => 'international',
					plan => 'isdn',
				},
			);
			$comp=$xml->first_elt('networkNode-Number');
			$comp->set_text($mes->pSRI->vlr);
		}
		#if ($mes->tcap->component->opcode=~/mt-forwardSM/ && $mes->tcap->component->type=~/ResultLast/){
			#if ($mes->tcap->app =~ /false/){
			#	my $m = $xml->first_elt('m');
			#	$m->insert_new_elt(
			#		application => ''
			#	);
			#	my $a=$xml->first_elt('application');
			#	$a->set_text('shortMsgMT-RelayContext-v3');
			#}
		#	my $tmp='sm-RP-UI';
		#	$comp->insert_new_elt(
		#		$tmp => '',
		#	);
		#	$comp=$xml->first_elt('sm-RP-UI');
		#	$comp->set_text($mes->pMT->sm_rp_ui->res);
		#}
	}
	return $xml->sprint;
}
sub appSMS {
	my $txt=shift;
	my $mes=&recvXML($txt);
	&printMessage($mes);
	if ($mes->tcap->localID=~/false/) {
		$mes=&allocLocalID($mes);
	}
	my $answer = &initMessage();
	#mtp
	$answer->mtp->remotePC($mes->mtp->remotePC);
	$answer->mtp->localPC($mes->mtp->localPC);
	$answer->mtp->sls($mes->mtp->sls);
	#sccp
	$answer->sccp->a_route($own_smsc_route);
	$answer->sccp->a_gt($own_smsc_gt);
	$answer->sccp->b_ssn($mes->sccp->a_ssn);
	$answer->sccp->b_route($mes->sccp->a_route);
	$answer->sccp->b_gt($mes->sccp->a_gt);
	#tcap
	$answer->tcap->remoteID($mes->tcap->remoteID);
	$answer->tcap->localID($mes->tcap->localID);
	$answer->tcap->app($mes->tcap->app);
	if ($mes->tcap->component->status=~/true/) {
		$answer->tcap->component->opcode($mes->tcap->component->opcode);
		$answer->tcap->component->remoteCID($mes->tcap->component->remoteCID);
		if ($mes->tcap->component->opcode=~/sendRoutingInfoForSM/ && $mes->tcap->reqType=~/Begin/) {
			$answer->sccp->a_ssn($own_hlr_ssn);
			$answer->tcap->reqType('End');
			$answer->tcap->dialogType('AARE');
			$answer->tcap->component->status('true');
			$answer->tcap->component->type('ResultLast');
			my $imsi=&allocImsi();
			$answer->pSRI->imsi($imsi);
			$answer->pSRI->vlr($own_smsc_gt);
		}
		if ($mes->tcap->component->opcode=~/mt-forwardSM/ && $mes->tcap->reqType=~/Begin/ ) {
			$answer->sccp->a_ssn($own_smsc_ssn);
			$answer->tcap->reqType('End');
			$answer->tcap->dialogType('AARE');
			$answer->tcap->component->status('true');
			$answer->tcap->component->type('ResultLast');
			$answer->pMT->sm_rp_ui->res('0000');
			&deallocImsi($mes->pMT->sm_rp_da);
		}
		if ($mes->tcap->component->opcode=~/mt-forwardSM/ && $mes->tcap->reqType=~/Continue/ ) {
			$answer->sccp->a_ssn($own_smsc_ssn);
			$answer->tcap->reqType('End');
			$answer->tcap->dialogType('false');
			$answer->tcap->component->status('true');
			$answer->tcap->component->type('ResultLast');
		}
	} else {
		if ($mes->tcap->app=~/shortMsgMT-RelayContext-v3/ && $mes->tcap->reqType=~/Begin/){
			$answer->sccp->a_ssn($own_smsc_ssn);
			$answer->tcap->reqType('Continue');
			$answer->tcap->dialogType('AARE');
			$answer->tcap->component->status('false');
		}
	}
	&printMessage($answer);
	my $send=&sendXML($answer);
	print "Send\n$send";
	return $send;
}
