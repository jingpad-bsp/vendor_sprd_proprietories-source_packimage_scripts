#!/usr/bin/env python
from struct import pack, unpack
import subprocess,os,sys,struct,array
from Crypto.PublicKey import RSA
from Crypto.Util.number import long_to_bytes

def get_head_offset(tos_img,tos_len):
    secpos = tos_img.find('dynamic_ta_head')
    if secpos < 0:
        print "there is no head!!!"
        return 0
    else:
        return  secpos

def main():
    f = open(sys.argv[2] + '/sprd/config/dynamic_ta_privatekey.pem', 'r')
    key = RSA.importKey(f.read())
    f.close

    fv = open(sys.argv[2] + '/sprd/config/vdsp_firmware_privatekey.pem', 'r')
    key2 = RSA.importKey(fv.read())
    fv.close

    filename = sys.argv[1] + '/tos.bin'
    if os.path.exists(filename):
        f1 = open(filename,'rb+')
        bindata = f1.read()
        bin_len = len(bindata)
        offset = get_head_offset(bindata,bin_len)
        if offset == 0:
            f1.close()
            print "there is no head,process will stop!!!"
        else:
            f1.seek(offset+16,0)
            i = 0
            pubkeylen = key.publickey().size()
            pubkey_e = key.publickey().e
            datalen = struct.pack("<I",pubkeylen)
            data_e = struct.pack("<I",pubkey_e)
            length = 4+4+len(long_to_bytes(key.publickey().n) )
            headlength = struct.pack("<I",length)
            data_3 = '%s%s%s' % (headlength,datalen,data_e)
            f1.write(data_3)
            for x in array.array("B", long_to_bytes(key.publickey().n)):
	        i = i + 1;
	        data_n = struct.pack("<B",x)
	        f1.write(data_n)

            f1.seek(0,1)
            i = 0
            v_pubkeylen = 1 + key2.publickey().size()
            v_pubkey_e = key2.publickey().e
            v_datalen = struct.pack("<I",v_pubkeylen)
            v_data_e = struct.pack(">I",v_pubkey_e)
            v_length = 4+4+len(long_to_bytes(key2.publickey().n) )
            v_headlength = struct.pack("<I",v_length)
            v_data_3 = '%s%s%s' % (v_headlength,v_datalen,v_data_e)
            f1.write(v_data_3)
            for y in array.array("B", long_to_bytes(key2.publickey().n)):
	        i = i + 1;
	        data_v = struct.pack("<B",y)
	        f1.write(data_v)

            f1.close()
    else:
        print "File is not accessible!!!"

if __name__ == "__main__":
	main()
