from invoke import task
import os
import json


def get_test_tag(component):
    slug = os.environ['CI_COMMIT_SHA']
    container_test_image = f'registry.gitlab.com/sharmaudi/forgeops/{component}:{slug}'
    return container_test_image


@task
def build(c):
    component = 'obp-opendj-6.0.0'
    container_test_image = get_test_tag(component)
    c.run(f'docker build -t {container_test_image} .')
    c.run(f'docker push {container_test_image}')


@task
def release(c):
    branch_name = os.environ['CI_COMMIT_REF_NAME']
    component = 'obp-opendj-6.0.0'
    if branch_name in ['v5.5', 'v6.0', 'master']:
        container_test_image = get_test_tag(component)
        container_release_image = f'registry.gitlab.com/sharmaudi/forgeops/{component}:latest'
        c.run(f'docker pull {container_test_image}')
        c.run(f'docker tag {container_test_image} {container_release_image}')
        c.run(f'docker push {container_release_image}')


@task
def deploy(c):
    project_id = os.environ['GCP_PROJECT_ID']
    compute_zone = os.environ['GCP_COMPUTE_ZONE']
    cluster_name = os.environ['GCP_CLUSTER_NAME']
    component = 'obp-opendj-6.0.0'
    deployment_name = 'userstore'
    image = get_test_tag(component)
    patch_json = [
        {"op": "replace",
         "path": "/spec/template/spec/containers/0/image",
         "value": image},
        {"op": "replace",
         "path": "/spec/template/spec/initContainers/0/image",
         "value": image}
    ]
    patch = f'kubectl patch statefulset {deployment_name} --type=\'json\' -p=\'{json.dumps(patch_json)}\''
    c.run(f'gcloud config set project {project_id}')
    c.run(f'gcloud config set compute/zone {compute_zone}')
    c.run('echo -n ${GCP_SERVICE_ACCOUNT}|base64 -d > ${HOME}/gcloud-service-key.json')
    c.run('gcloud auth activate-service-account --key-file ${HOME}/gcloud-service-key.json')
    c.run(f'gcloud container clusters get-credentials {cluster_name}')
    c.run('kubectl apply -f kube')
    print(f"Patch Command: {patch}")
    c.run(f'{patch}')
    c.run(f'kubectl rollout status sts/{deployment_name}')
    print("All good.")
