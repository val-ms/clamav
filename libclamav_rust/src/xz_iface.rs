/*use std::{
    convert::TryInto,
    sync::Mutex, 
};*/

//use once_cell::sync::Lazy;
use xz2::stream::{
    Stream,
//    IGNORE_CHECK,
    Action,
    Status,
};

use log::{debug/*, error, warn*/};
use libc::c_void;
use std::ffi::CStr;
use std::os::raw::c_char;

#[repr(C)]
enum RxzStatus {
    OK = 0,
    StreamEnd = 1,
    UnsupportedCheck = 2,
    MemError = 3,
    FormatError = 4,
    OptionsError = 5,
    DataError = 6,
    BufError = 7,
}

#[repr(C, packed)]
struct RxzReturn {
    status: RxzStatus,
    consumed: usize,
}

#[repr(C)]
struct Map {
    _bytes: [u8; 0],
    _marker: std::marker::PhantomData<(*mut u8, core::marker::PhantomPinned)>,
}

/*
 * Decode an lzma (or xz) stream and store in a buffer.
 * 
 * @param in_buf input buffer to be decoded
 * @param in_len length of input buffer in bytes
 * @param out_buf output buffer to store decoded data
 * 
 * @return the number of bytes decoded, or negative on error
 */
#[no_mangle]
pub extern "C" fn clrs_lzma_decode(
    in_buf: *mut *mut c_void,
    in_len: usize,
    out_buf: *mut u8,
) -> i64 {
   
    if in_buf.is_null() {
        return -1;
    }

    if in_len == 0 {
        return 0;
    }

    // create a slice from the C input buffer ptr
    let in_buf = unsafe { std::slice::from_raw_parts_mut(*in_buf, in_len) };
    let in_buf = in_buf.as_mut_ptr() as *mut c_char;
    debug!("????????????? map? {:?}\n", in_buf);

    // setup the decoder
    let mut decoder = Stream::new_lzma_decoder(u64::MAX).unwrap();

    // decode into a vector
    let mut out_vec = vec![];
    let map = unsafe {
        CStr::from_ptr(in_buf).to_string_lossy().into_owned()
    };
    let map = map.as_bytes();

    match xz2::stream::Stream::process_vec(&mut decoder, map, &mut out_vec, Action::Run) {
        Ok(status) => 
            match status {
                Status::Ok => debug!("No issue decoding lzma stream\n"),
                Status::StreamEnd => debug!("Reached end of lzma stream\n"),
                Status::GetCheck => debug!("GetCheck tiggered\n"),
                Status::MemNeeded => debug!("Ran out of memory\n"),
        },
        Err(_) => return -2,
    }

    // return the number of bytes within the decoded vector
    let out_len = out_vec.len();

    debug!(">>>>>>>>>>>>>> 11111111 Outlen: {}\n", out_len);
    debug!("Total in = {}, total out = {}\n", decoder.total_in(), decoder.total_out());

    // expose a pointer to the vector's buffer to the C code
    // THIS WILL BE OWNED BY C STUFFS, SO CLEAN THIS UP USING THE PROVIDED RUST DESTRUCTOR
    let out_vec = out_vec.as_mut_slice();
    let out_buf = out_vec.as_mut_ptr();

    debug!("<<<<<<<<<<<<<<<< 22222222 Outlen: {}\n", out_vec.len());
    
    // explicitly pass memory ownership to C
    std::mem::forget(out_vec);

    if out_len > 0 {
        return out_len as i64;
    } else if out_len == 0 {
        return  0;
    } else {
        return -1;
    }
}

#[no_mangle]
pub unsafe extern "C" fn clrs_free_buffer(ptr: *mut u8, len: usize) {
    if ptr.is_null() {
        return;
    }
    let _ = std::slice::from_raw_parts(ptr, len);
}