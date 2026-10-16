import { defineRailway, github, project, service, volume } from "railway/iac";

// Railway setup for the web app. Replaces railway.json (Config as Code is
// read until 2026-12-01). Preview with `railway config plan` before
// `railway config apply`.
//
// Only the resources declared here belong to this file; the old Postgres
// service is left alone. Variables (RAILS_MASTER_KEY etc.) stay managed in
// the Railway dashboard and are never written here.
export const partial = "tokyo-mizo-church-portal";

export default defineRailway(() => {
  // Holds the SQLite database (production.sqlite3). Never detach or delete.
  const storage = volume("tokyo-mizo-church-portal-volume", {
    region: "asia-southeast1-eqsg3a",
    sizeMB: 5000,
  });

  const web = service("tokyo-mizo-church-portal", {
    source: github("thadomaloma/tokyo-mizo-church-portal", { branch: "main", checkSuites: false }),
    build: { builder: "DOCKERFILE" },
    deploy: {
      healthcheckPath: "/up",
      healthcheckTimeout: 300,
      restartPolicyType: "ON_FAILURE",
      restartPolicyMaxRetries: 10,
      drainingSeconds: 30,
    },
    replicas: { "asia-southeast1-eqsg3a": 1 },
    volumeMounts: { "/rails/storage": storage },
  });

  return project("tokyo-mizo-church", {
    variables: { managed: false },
    resources: [web, storage],
  });
});
