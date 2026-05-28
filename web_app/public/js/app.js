document.addEventListener('DOMContentLoaded', async () => {
    const urlParams = new URLSearchParams(window.location.search);
    const tagId = urlParams.get('id');

    const loadingEl = document.getElementById('loading');
    const errorEl = document.getElementById('error-state');
    const contentEl = document.getElementById('content');
    
    // Check if tag ID is provided
    if (!tagId) {
        showError("No tag ID provided in the URL.");
        return;
    }

    try {
        // Fetch Tag and Pet data from Supabase
        const { data: tagData, error } = await supabaseClient
            .from('tags')
            .select(`
                id,
                is_active,
                pets (
                    name,
                    photo_url,
                    public_notes
                )
            `)
            .eq('id', tagId)
            .single();

        if (error || !tagData) {
            console.error(error);
            showError("Tag not found.");
            return;
        }

        if (!tagData.is_active) {
            showError("This tag is currently inactive.");
            return;
        }

        const pet = tagData.pets;
        renderPet(pet);
        
        // Setup Notify Button
        const notifyBtn = document.getElementById('notify-btn');
        notifyBtn.addEventListener('click', () => notifyOwner(tagId, notifyBtn));

    } catch (err) {
        console.error(err);
        showError("An unexpected error occurred.");
    }

    function renderPet(pet) {
        document.getElementById('pet-name').innerText = pet.name || "Unknown Pet";
        
        const notesEl = document.getElementById('pet-notes');
        if (pet.public_notes && pet.public_notes.trim() !== '') {
            notesEl.innerText = pet.public_notes;
        }

        const photoEl = document.getElementById('pet-photo');
        const noPhotoEl = document.getElementById('no-photo');
        
        if (pet.photo_url) {
            photoEl.src = pet.photo_url;
            photoEl.classList.remove('hidden');
        } else {
            noPhotoEl.classList.remove('hidden');
            noPhotoEl.classList.add('flex');
        }

        // Hide loading, show content
        loadingEl.classList.add('hidden');
        contentEl.classList.remove('hidden');
    }

    function showError(message) {
        loadingEl.classList.add('hidden');
        document.getElementById('error-message').innerText = message;
        errorEl.classList.remove('hidden');
        errorEl.classList.add('flex');
    }

    async function notifyOwner(tagId, btn) {
        btn.disabled = true;
        btn.classList.add('opacity-75', 'cursor-not-allowed');
        const originalText = btn.innerHTML;
        btn.innerText = "Getting Location...";

        let lat = null;
        let lng = null;

        try {
            // Try to get geolocation
            const position = await new Promise((resolve, reject) => {
                if (!navigator.geolocation) resolve(null);
                navigator.geolocation.getCurrentPosition(resolve, () => resolve(null), { timeout: 5000 });
            });

            if (position) {
                lat = position.coords.latitude;
                lng = position.coords.longitude;
            }

            btn.innerText = "Sending Notification...";

            const { data, error } = await supabaseClient.functions.invoke('notify-owner', {
                body: { tag_id: tagId, lat: lat, lng: lng }
            });

            if (error) {
                // Supabase JS wrapper throws an error object for non-2xx statuses
                if (error.context && error.context.status === 429) {
                    throw new Error("The owner has already been notified recently. Please wait.");
                }
                throw new Error("Failed to send notification.");
            }

            // Show success
            btn.classList.add('hidden');
            document.getElementById('success-msg').classList.remove('hidden');

        } catch (err) {
            console.error("Notification Error:", err);
            alert(err.message || "Failed to notify the owner. Please try again.");
            btn.disabled = false;
            btn.classList.remove('opacity-75', 'cursor-not-allowed');
            btn.innerHTML = originalText;
        }
    }
});