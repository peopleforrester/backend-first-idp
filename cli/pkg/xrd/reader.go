// ABOUTME: XRD reader — discovers available resource types from XRD files.
// ABOUTME: Reads platform-api/xrds/ to show types, fields, enums, and defaults.
package xrd

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"gopkg.in/yaml.v3"
)

// ResourceInfo holds discovered information about a platform resource type.
type ResourceInfo struct {
	Kind      string
	Plural    string
	ClaimKind string
	Fields    []FieldInfo
}

// FieldInfo describes a spec field in an XRD.
type FieldInfo struct {
	Name     string
	Type     string
	Required bool
	Default  interface{}
	Enum     []string
}

// DiscoverTypes reads all XRD files and returns resource information.
func DiscoverTypes(repoRoot string) ([]ResourceInfo, error) {
	xrdDir := filepath.Join(repoRoot, "platform-api", "xrds")
	entries, err := os.ReadDir(xrdDir)
	if err != nil {
		return nil, fmt.Errorf("reading XRD directory: %w", err)
	}

	var resources []ResourceInfo
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".yaml") {
			continue
		}
		info, err := parseXRD(filepath.Join(xrdDir, e.Name()))
		if err != nil {
			continue
		}
		resources = append(resources, info)
	}
	return resources, nil
}

func parseXRD(path string) (ResourceInfo, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return ResourceInfo{}, err
	}

	var doc map[string]interface{}
	if err := yaml.Unmarshal(data, &doc); err != nil {
		return ResourceInfo{}, err
	}

	spec, _ := doc["spec"].(map[string]interface{})
	names, _ := spec["names"].(map[string]interface{})
	claimNames, _ := spec["claimNames"].(map[string]interface{})

	info := ResourceInfo{
		Kind:      getString(names, "kind"),
		Plural:    getString(names, "plural"),
		ClaimKind: getString(claimNames, "kind"),
	}

	versions, _ := spec["versions"].([]interface{})
	if len(versions) > 0 {
		v, _ := versions[0].(map[string]interface{})
		schema, _ := v["schema"].(map[string]interface{})
		openAPI, _ := schema["openAPIV3Schema"].(map[string]interface{})
		props, _ := openAPI["properties"].(map[string]interface{})
		specDef, _ := props["spec"].(map[string]interface{})
		specProps, _ := specDef["properties"].(map[string]interface{})

		required := getStringSlice(specDef, "required")
		requiredSet := make(map[string]bool)
		for _, r := range required {
			requiredSet[r] = true
		}

		for name, rawField := range specProps {
			field, _ := rawField.(map[string]interface{})
			fi := FieldInfo{
				Name:     name,
				Type:     getString(field, "type"),
				Required: requiredSet[name],
				Default:  field["default"],
				Enum:     getStringSlice(field, "enum"),
			}
			info.Fields = append(info.Fields, fi)
		}
	}

	return info, nil
}

func getString(m map[string]interface{}, key string) string {
	v, _ := m[key].(string)
	return v
}

func getStringSlice(m map[string]interface{}, key string) []string {
	raw, _ := m[key].([]interface{})
	var result []string
	for _, v := range raw {
		if s, ok := v.(string); ok {
			result = append(result, s)
		}
	}
	return result
}
