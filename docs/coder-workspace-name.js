/**
 * Shared workspace name helpers for start.coder.ddev.com (drupal-core + drupal-issue).
 */
(function (global) {
  'use strict';

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
    if (branchOptionCount > 1 && branchName) {
      return sanitizeWorkspaceName(base + '-' + branchName);
    }
    return sanitizeWorkspaceName(base + '-' + nidSeg);
  }

  global.CoderWorkspace = {
    PROFILE_SLUG: PROFILE_SLUG,
    VERSION_SLUG: VERSION_SLUG,
    sanitizeWorkspaceName: sanitizeWorkspaceName,
    workspaceNameFromCoreChoices: workspaceNameFromCoreChoices,
    suggestedIssueForkWorkspaceName: suggestedIssueForkWorkspaceName,
  };
})(typeof window !== 'undefined' ? window : this);
