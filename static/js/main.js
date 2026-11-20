// =====================================================================
// HOSTEL MAINTENANCE AND COMPLAINT TRACKER
// Client-side interactions & dynamic API helpers
// =====================================================================

document.addEventListener('DOMContentLoaded', () => {
    // 1. Mark Notifications as Read
    const markReadBtn = document.getElementById('btn-mark-notifications-read');
    if (markReadBtn) {
        markReadBtn.addEventListener('click', async () => {
            try {
                const res = await fetch('/notifications/mark-read', { method: 'POST' });
                const data = await res.json();
                if (data.success) {
                    const badge = document.getElementById('notification-badge');
                    if (badge) badge.style.display = 'none';
                    document.querySelectorAll('.notification-item.unread').forEach(el => {
                        el.classList.remove('unread', 'bg-light');
                    });
                }
            } catch (err) {
                console.error('Error marking notifications as read:', err);
            }
        });
    }

    // 2. Load Complaint Audit History Modal
    const historyModalEl = document.getElementById('historyModal');
    if (historyModalEl) {
        historyModalEl.addEventListener('show.bs.modal', async (event) => {
            const button = event.relatedTarget;
            const complaintId = button.getAttribute('data-complaint-id');
            const title = button.getAttribute('data-complaint-title');
            
            document.getElementById('historyModalComplaintTitle').innerText = `Complaint #${complaintId} - ${title}`;
            const timelineContainer = document.getElementById('historyTimelineContainer');
            timelineContainer.innerHTML = '<div class="text-center py-4"><div class="spinner-border text-primary" role="status"></div></div>';

            try {
                const res = await fetch(`/api/complaint/${complaintId}/history`);
                const data = await res.json();
                if (data.success && data.history.length > 0) {
                    let html = '<div class="list-group list-group-flush">';
                    data.history.forEach((h, idx) => {
                        html += `
                            <div class="list-group-item px-0 py-3">
                                <div class="d-flex w-100 justify-content-between align-items-center">
                                    <h6 class="mb-1 text-primary fw-bold">
                                        <i class="bi bi-arrow-right-circle-fill me-1"></i> ${h.action_type}
                                    </h6>
                                    <small class="text-muted"><i class="bi bi-clock me-1"></i>${h.changed_at}</small>
                                </div>
                                <p class="mb-1 text-secondary small">${h.remarks || 'No remarks recorded.'}</p>
                                <div class="d-flex justify-content-between align-items-center mt-1">
                                    <span class="badge bg-secondary">${h.new_status}</span>
                                    <small class="text-muted">By: <strong>${h.actor_name || 'System Trigger'}</strong> (${h.actor_role || 'Automated'})</small>
                                </div>
                            </div>
                        `;
                    });
                    html += '</div>';
                    timelineContainer.innerHTML = html;
                } else {
                    timelineContainer.innerHTML = '<div class="alert alert-info">No history recorded yet for this complaint.</div>';
                }
            } catch (err) {
                timelineContainer.innerHTML = `<div class="alert alert-danger">Error loading history: ${err.message}</div>`;
            }
        });
    }

    // 3. Populate Assign Staff Modal in Warden Dashboard
    const assignModalEl = document.getElementById('assignStaffModal');
    if (assignModalEl) {
        assignModalEl.addEventListener('show.bs.modal', (event) => {
            const button = event.relatedTarget;
            const complaintId = button.getAttribute('data-complaint-id');
            const category = button.getAttribute('data-category');
            const title = button.getAttribute('data-title');

            document.getElementById('assignModalComplaintId').value = complaintId;
            document.getElementById('assignModalComplaintText').innerText = `#${complaintId} - ${title} (${category})`;

            // Attempt to pre-select matching technician specialization
            const staffSelect = document.getElementById('assignModalStaffSelect');
            if (staffSelect) {
                for (let option of staffSelect.options) {
                    const spec = option.getAttribute('data-specialization');
                    if (spec && spec.toLowerCase() === category.toLowerCase()) {
                        option.selected = true;
                        break;
                    }
                }
            }
        });
    }

    // 4. Populate Resolve Modal in Warden Dashboard
    const resolveModalEl = document.getElementById('resolveComplaintModal');
    if (resolveModalEl) {
        resolveModalEl.addEventListener('show.bs.modal', (event) => {
            const button = event.relatedTarget;
            const complaintId = button.getAttribute('data-complaint-id');
            const title = button.getAttribute('data-title');

            document.getElementById('resolveModalComplaintId').value = complaintId;
            document.getElementById('resolveModalTitle').innerText = `#${complaintId} - ${title}`;
        });
    }

    // 5. Populate Update Task Modal in Staff Dashboard
    const updateTaskModalEl = document.getElementById('updateTaskModal');
    if (updateTaskModalEl) {
        updateTaskModalEl.addEventListener('show.bs.modal', (event) => {
            const button = event.relatedTarget;
            const complaintId = button.getAttribute('data-complaint-id');
            const currentStatus = button.getAttribute('data-current-status');
            const title = button.getAttribute('data-title');

            document.getElementById('updateModalComplaintId').value = complaintId;
            document.getElementById('updateModalTitle').innerText = `#${complaintId} - ${title}`;

            const statusSelect = document.getElementById('updateModalStatusSelect');
            if (statusSelect) {
                if (currentStatus === 'Assigned') {
                    statusSelect.value = 'In Progress';
                } else if (currentStatus === 'In Progress') {
                    statusSelect.value = 'Completed';
                }
            }
        });
    }
});
