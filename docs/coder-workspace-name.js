/**
 * Shared workspace name helpers for start.coder.ddev.com (drupal-core + drupal-issue).
 */
(function (global) {
  'use strict';

  const MAX_WORKSPACE_NAME_LENGTH = 32;
  const WORKSPACE_NAME_TOO_LONG_MESSAGE = 'Workspace Name cannot be longer than 32 characters';

  const PROFILE_SLUG = {
    demo_umami: 'umami',
    minimal: 'minimal',
    standard: 'standard',
  };

  const VERSION_SLUG = {
    10: '10x',
    11: '11x',
    12: '12x',
  };

  function sanitizeWorkspaceName(name) {
    return String(name)
      .toLowerCase()
      .replace(/[^a-z0-9-]/g, '-')
      .replace(/-+/g, '-')
      .replace(/^-|-$/g, '');
  }

  /**
   * Plain Drupal core workspace (no issue fork): {major}x-{profileSlug}, e.g. 12x-umami.
   *
   * @param {string} drupalMajor
   * @param {string} installProfile machine value (e.g. demo_umami)
   * @returns {string}
   */
  function workspaceNameFromCoreChoices(drupalMajor, installProfile) {
    const verKey = String(drupalMajor);
    const verSlug = VERSION_SLUG[verKey] || (verKey + 'x');
    const slug = PROFILE_SLUG[installProfile] || String(installProfile).replace(/_/g, '-');
    return verSlug + '-' + slug;
  }

  /**
   * Issue picker: version + profile + (branch name if multiple branch options, else issue NID).
   * Falls back to the issue NID when a branch-based name exceeds MAX_WORKSPACE_NAME_LENGTH.
   *
   * @param {string} drupalMajor
   * @param {string} installProfile
   * @param {string|number} issueNid
   * @param {string} branchName selected branch
   * @param {number} branchOptionCount branches shown in the picker (>1 means disambiguate with branch)
   * @returns {string}
   */
  function suggestedIssueForkWorkspaceName(drupalMajor, installProfile, issueNid, branchName, branchOptionCount) {
    const base = workspaceNameFromCoreChoices(drupalMajor, installProfile);
    const nidSeg = String(issueNid);
    const withNid = sanitizeWorkspaceName(base + '-' + nidSeg);

    if (branchOptionCount > 1 && branchName) {
      const withBranch = sanitizeWorkspaceName(base + '-' + branchName);
      if (withBranch.length > MAX_WORKSPACE_NAME_LENGTH) {
        return withNid;
      }
      return withBranch;
    }

    return withNid;
  }

  /**
   * @param {string} name raw or sanitized workspace name candidate
   * @returns {{ valid: boolean, sanitized: string, message: string }}
   */
  function validateWorkspaceName(name) {
    const sanitized = sanitizeWorkspaceName(name);
    if (sanitized.length > MAX_WORKSPACE_NAME_LENGTH) {
      return {
        valid: false,
        sanitized: sanitized,
        message: WORKSPACE_NAME_TOO_LONG_MESSAGE,
      };
    }
    return {
      valid: true,
      sanitized: sanitized,
      message: '',
    };
  }

  /**
   * Show or clear inline validation on a workspace name field.
   *
   * @param {string} inputId
   * @param {string} errorId
   * @returns {{ valid: boolean, sanitized: string, message: string }|null}
   */
  function applyWorkspaceNameFieldValidation(inputId, errorId) {
    const input = document.getElementById(inputId);
    const errorEl = document.getElementById(errorId);
    if (!input || !errorEl) {
      return null;
    }

    const result = validateWorkspaceName(input.value.trim());
    if (result.valid) {
      input.removeAttribute('aria-invalid');
      errorEl.textContent = '';
      errorEl.hidden = true;
    } else {
      input.setAttribute('aria-invalid', 'true');
      errorEl.textContent = result.message;
      errorEl.hidden = false;
    }

    return result;
  }

  /**
   * @param {string} inputId
   * @param {string} errorId
   * @param {function(): void} [onChange]
   */
  function bindWorkspaceNameFieldValidation(inputId, errorId, onChange) {
    const input = document.getElementById(inputId);
    if (!input) {
      return;
    }

    const run = function () {
      applyWorkspaceNameFieldValidation(inputId, errorId);
      if (onChange) {
        onChange();
      }
    };

    input.addEventListener('input', run);
    input.addEventListener('change', run);
  }

  global.CoderWorkspace = {
    MAX_WORKSPACE_NAME_LENGTH: MAX_WORKSPACE_NAME_LENGTH,
    WORKSPACE_NAME_TOO_LONG_MESSAGE: WORKSPACE_NAME_TOO_LONG_MESSAGE,
    PROFILE_SLUG: PROFILE_SLUG,
    VERSION_SLUG: VERSION_SLUG,
    sanitizeWorkspaceName: sanitizeWorkspaceName,
    workspaceNameFromCoreChoices: workspaceNameFromCoreChoices,
    suggestedIssueForkWorkspaceName: suggestedIssueForkWorkspaceName,
    validateWorkspaceName: validateWorkspaceName,
    applyWorkspaceNameFieldValidation: applyWorkspaceNameFieldValidation,
    bindWorkspaceNameFieldValidation: bindWorkspaceNameFieldValidation,
  };
})(typeof window !== 'undefined' ? window : this);
