source /opt/workshops/elastic-retry.sh
export $(curl http://kubernetes-vm:9000/env | xargs)

echo "Enable Streams"
enable_streams() {
    local http_status=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$KIBANA_URL/api/streams/_enable" \
    --header 'Content-Type: application/json' \
    --header "kbn-xsrf: true" \
    --header "Authorization: Basic $ELASTICSEARCH_AUTH_BASE64" \
    --header 'x-elastic-internal-origin: Kibana')

    if echo $http_status | grep -q '^2'; then
        echo "Enabled Streams: $http_status"
        return 0
    else
        echo "Failed to enable Streams. HTTP status: $http_status"
        return 1
    fi
}
retry_command_lin enable_streams

echo "Enable Significant Events"
enable_significant_events() {
    local http_status=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$KIBANA_URL/internal/kibana/settings" \
    --header 'Content-Type: application/json' \
    --header "kbn-xsrf: true" \
    --header "Authorization: Basic $ELASTICSEARCH_AUTH_BASE64" \
    --header 'x-elastic-internal-origin: Kibana' \
    -d '{"changes":{"observability:streamsEnableSignificantEvents":true}}')

    if echo $http_status | grep -q '^2'; then
        echo "Enabled Significant Events: $http_status"
        return 0
    else
        echo "Failed to enable Significant Events. HTTP status: $http_status"
        return 1
    fi
}
retry_command_lin enable_significant_events

# ------------- CACHING

echo "Disable field caching"
disable_field_caching() {
    local http_status=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$KIBANA_URL/internal/kibana/settings" \
    --header 'Content-Type: application/json' \
    --header "kbn-xsrf: true" \
    --header "Authorization: Basic $ELASTICSEARCH_AUTH_BASE64" \
    --header 'x-elastic-internal-origin: Kibana' \
    -d '{"changes":{"data_views:cache_max_age":0}}')

    if echo $http_status | grep -q '^2'; then
        echo "Disabled field caching: $http_status"
        return 0
    else
        echo "Failed to disable field caching. HTTP status: $http_status"
        return 1
    fi
}
retry_command_lin disable_field_caching

# ------------- DATAVIEW

echo "/api/data_views/data_view"
curl -X POST "$KIBANA_URL/api/data_views/data_view" \
    --header 'Content-Type: application/json' \
    --header "kbn-xsrf: true" \
    --header "Authorization: ApiKey $ELASTICSEARCH_APIKEY" \
    -d '
{
  "data_view": {
    "name": "logs-wired",
    "title": "logs.*,logs"
  }
}'

# ------------- TEMPLATE

echo "/_component_template/logs-otel@custom"
curl -X POST "$ELASTICSEARCH_URL/_component_template/logs-otel@custom" \
    --header 'Content-Type: application/json' \
    --header "Authorization: ApiKey $ELASTICSEARCH_APIKEY" \
    -d '
{
  "template": {
    "mappings": {
      "dynamic_templates": [
        {
          "complex_attributes": {
            "path_match": [
              "resource.attributes.*",
              "scope.attributes.*",
              "attributes.*"
            ],
            "mapping": {
              "type": "object",
              "subobjects": false
            },
            "match_mapping_type": "object"
          }
        }
      ]
    }
  }
}'
