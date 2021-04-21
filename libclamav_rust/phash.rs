// Sample c-facing function call
use std::io::Write;
use std::{mem, ptr, slice};

use std::time::{SystemTime, UNIX_EPOCH};

extern crate image;
extern crate img_hash;

#[no_mangle]
pub extern "C" fn generate_phash(
    file_bytes: *const u8,
    file_size: usize,
    phash: *mut u8,
    phash_len: usize,
) -> usize {
    let hash_bytes_copied;

    if file_bytes.is_null() {
        println!("invalid NULL pointer for image input buffer");
        return 0;
    }
    if phash.is_null() {
        println!("invalid NULL pointer for phash output buffer");
        return 0;
    }

    let buffer: &[u8] = unsafe { slice::from_raw_parts(file_bytes, file_size) };
    println!("generate_phash called with file_size={}", file_size);

    let start = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .expect("Time went backwards");

    let image_result = image::load_from_memory(buffer);

    let end = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .expect("Time went backwards");

    println!("Time to load an image: {:?}", end - start);

    let start = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .expect("Time went backwards");

    match image_result {
        Ok(image) => {
            let hasher = img_hash::HasherConfig::new()
                .hash_size(8, 8)
                .resize_filter(img_hash::FilterType::Triangle)
                // .preproc_dct()
                .hash_alg(img_hash::HashAlg::Mean)
                .to_hasher();
            let hash = hasher.hash_image(&image);

            let end = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .expect("Time went backwards");

            println!("Time to phash an image: {:?}", end - start);

            println!("Image hash: {}", hash.to_base64());

            let hash_bytes = hash.as_bytes();
            if phash_len < hash_bytes.len() {
                println!("input buffer is too small to hold the phash.");
                return 0;
            }
            unsafe {
                phash.copy_from(hash_bytes.as_ptr(), hash_bytes.len());
                hash_bytes_copied = hash_bytes.len();
            }
        }
        Err(err) => {
            println!("Failed to load image from memory {}", err);
            return 0;
        }
    }

    std::io::stdout().flush().unwrap();

    hash_bytes_copied
}
