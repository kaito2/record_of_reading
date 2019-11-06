roles=( roles/clouddebugger.agent \
        roles/cloudprofiler.agent \
        roles/cloudtrace.agent \
        roles/container.admin \
        roles/errorreporting.writer \
        roles/logging.logWriter \
        roles/monitoring.metricWriter \
        roles/monitoring.editor )

for role in ${roles[@]}
do
    gcloud projects add-iam-policy-binding ${PROJECT_ID} \
           --member serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com \
           --role ${role}
done
