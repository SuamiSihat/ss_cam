/**
 * SS-CAM Plain Language Copy & Canonical Terminology Dictionary
 * Phase 4: Copywriting & System Message Standardization
 */

export const copy = {
  // ─── CANONICAL TERMS ──────────────────────────────────────────────
  terms: {
    request: 'Request',
    requests: 'Requests',
    project: 'Project',
    projects: 'Projects',
    task: 'Task',
    tasks: 'Tasks',
    deliverable: 'Deliverable',
    deliverables: 'Deliverables',
    file: 'File',
    files: 'Files',
    team: 'Team',
    teamMember: 'Team member',
    signIn: 'Sign in',
    signOut: 'Sign out',
    delete: 'Delete',
    create: 'Create',
    approval: 'Approval',
    approvals: 'Approvals',
    sharedDrive: 'Shared drive',
    printCheck: 'Print check',
    studioPerformance: 'Studio performance',
    rolesAndPermissions: 'Roles and permissions',
    chatNotification: 'Chat notification link',
    viewDetails: 'View details'
  },

  // ─── SUCCESS MESSAGES (No exclamation marks) ──────────────────────
  success: {
    saved: 'Changes saved',
    created: 'Created successfully',
    deleted: 'Deleted successfully',
    updated: 'Updated successfully',
    uploaded: 'File uploaded',
    passwordChanged: 'Password updated',
    linkCopied: 'Link copied to clipboard',
    requestSubmitted: 'Request submitted',
    approved: 'Deliverable approved',
    revisionRequested: 'Revision requested',
    signedOut: 'Signed out'
  },

  // ─── ERROR MESSAGES (Plain language: what happened + what to do) ──
  error: {
    generic: "Something went wrong on our side. Please try again.",
    network: "Can't reach the server. Check your connection and try again.",
    sessionExpired: "Your session has expired. Please sign in again.",
    unauthorized: "You don't have permission to do that.",
    notFound: "We couldn't find what you're looking for.",
    fileTooLarge: "That file is too large. Please choose a file under 60 MB.",
    invalidFileType: "That file type isn't supported. Please upload an image, video, PDF, or artwork file.",
    saveFailed: "We couldn't save your changes. Please try again.",
    deleteFailed: "We couldn't delete this item. Please try again.",
    uploadFailed: "We couldn't upload your file. Please try again.",
    loadFailed: "We couldn't load the information. Please refresh the page.",
    createFailed: "We couldn't create that item. Please check the details and try again.",
    missingFields: "Please fill in all required fields before continuing.",
    passwordMismatch: "The passwords don't match. Please re-enter them.",
    passwordTooShort: "Your password must be at least 10 characters long.",
    invalidCredentials: "The username or password you entered isn't correct.",
    accountLocked: "This account has been temporarily locked for security. Please try again later or speak to an admin.",
    conflict: "A file or item with that name already exists.",
    cannotDeleteWithFiles: "This project contains files. Please verify the name to proceed."
  },

  // ─── DIALOG & CONFIRMATION TEXT ───────────────────────────────────
  dialog: {
    deleteProjectTitle: 'Delete project',
    deleteProjectMessage: "This will permanently delete the project and all of its files from the shared drive. This action cannot be undone.",
    deleteProjectConfirmPrompt: 'Type the project name to confirm:',
    deleteItemTitle: 'Confirm deletion',
    deleteItemMessage: 'Are you sure you want to permanently delete this item? This cannot be undone.',
    cancelRequestTitle: 'Cancel request',
    cancelRequestMessage: 'Are you sure you want to cancel this creative request?',
    revokeShareTitle: 'Revoke share link',
    revokeShareMessage: 'Anyone using this link will immediately lose access to the review files.',
    deletePinTitle: 'Delete comment pin',
    deletePinMessage: 'Are you sure you want to remove this visual annotation pin?',
    deleteTaskTitle: 'Delete task',
    deleteTaskMessage: 'Are you sure you want to permanently delete this task?',
    approveDeliverableTitle: 'Approve deliverable',
    approveDeliverableMessage: 'Are you sure you want to mark this deliverable as approved?',
    requestRevisionTitle: 'Request revision',
    requestRevisionMessage: 'Please confirm that you would like to request changes on this deliverable.',
    restoreVersionTitle: 'Restore earlier version',
    restoreVersionMessage: 'This will restore the selected version as the active deliverable. Existing files are preserved.'
  }
};

/**
 * Safely converts an error into a user-friendly plain language message.
 * Logs the technical details to console.error when appropriate.
 */
export function getErrorMessage(err: unknown, fallback?: string): string {
  if (!err) return fallback || copy.error.generic;

  if (err instanceof Error) {
    const msg = err.message || '';

    // Network / reachability errors
    if (/network|failed to fetch|cannot connect|connection/i.test(msg)) {
      return copy.error.network;
    }

    // Session expired / auth errors
    if (/session|expired|unauthorized|401/i.test(msg)) {
      return copy.error.sessionExpired;
    }

    // Permission errors
    if (/forbidden|permission|403|access/i.test(msg)) {
      return copy.error.unauthorized;
    }

    // File size errors
    if (/too large|payload too large|413|file size/i.test(msg)) {
      return copy.error.fileTooLarge;
    }

    // If message is already a clean plain language sentence without technical jargon, return it
    if (
      msg.length > 5 &&
      msg.length < 120 &&
      !/[{}[\]<>\\\/=]|error|exception|statuscode|sql|stack|undefined|null|enoent|eacces/i.test(msg)
    ) {
      // Remove any exclamation marks
      return msg.replace(/!+$/, '.');
    }
  }

  if (typeof err === 'string') {
    if (!/[{}[\]<>\\\/=]|error|exception|statuscode|sql|stack|undefined|null|enoent|eacces/i.test(err)) {
      return err.replace(/!+$/, '.');
    }
  }

  return fallback || copy.error.generic;
}

export default copy;
