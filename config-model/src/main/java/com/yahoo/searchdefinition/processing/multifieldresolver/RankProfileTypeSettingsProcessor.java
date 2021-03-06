// Copyright 2017 Yahoo Holdings. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.searchdefinition.processing.multifieldresolver;

import com.yahoo.config.application.api.DeployLogger;
import com.yahoo.search.query.profile.types.FieldDescription;
import com.yahoo.search.query.profile.types.FieldType;
import com.yahoo.search.query.profile.types.QueryProfileType;
import com.yahoo.search.query.profile.types.TensorFieldType;
import com.yahoo.searchdefinition.RankProfile;
import com.yahoo.searchdefinition.RankProfileRegistry;
import com.yahoo.searchdefinition.Search;
import com.yahoo.searchdefinition.document.Attribute;
import com.yahoo.searchdefinition.document.SDField;
import com.yahoo.searchdefinition.processing.Processor;
import com.yahoo.vespa.model.container.search.QueryProfiles;

import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Class that processes a search instance and sets type settings on all rank profiles.
 *
 * Currently, type settings are limited to the type of tensor attribute fields and tensor query features.
 *
 * @author geirst
 */
public class RankProfileTypeSettingsProcessor extends Processor {

    private static final Pattern queryFeaturePattern = Pattern.compile("query\\((\\w+)\\)$");

    public RankProfileTypeSettingsProcessor(Search search, DeployLogger deployLogger, RankProfileRegistry rankProfileRegistry, QueryProfiles queryProfiles) {
        super(search, deployLogger, rankProfileRegistry, queryProfiles);
    }

    @Override
    public void process() {
        processAttributeFields();
        processQueryProfileTypes();

    }

    private void processAttributeFields() {
        for (SDField field : search.allConcreteFields()) {
            Attribute attribute = field.getAttributes().get(field.getName());
            if (attribute != null && attribute.tensorType().isPresent()) {
                addAttributeTypeToRankProfiles(attribute.getName(), attribute.tensorType().get().toString());
            }
        }
    }

    private void addAttributeTypeToRankProfiles(String attributeName, String attributeType) {
        for (RankProfile profile : rankProfileRegistry.allRankProfiles()) {
            profile.addAttributeType(attributeName, attributeType);
        }
    }

    private void processQueryProfileTypes() {
        for (QueryProfileType queryProfileType : queryProfiles.getRegistry().getTypeRegistry().allComponents()) {
            for (Map.Entry<String, FieldDescription> fieldDescEntry : queryProfileType.fields().entrySet()) {
                processFieldDescription(fieldDescEntry.getValue());
            }
        }
    }

    private void processFieldDescription(FieldDescription fieldDescription) {
        String fieldName = fieldDescription.getName();
        FieldType fieldType = fieldDescription.getType();
        if (fieldType instanceof TensorFieldType) {
            TensorFieldType tensorFieldType = (TensorFieldType)fieldType;
            Matcher matcher = queryFeaturePattern.matcher(fieldName);
            if (tensorFieldType.type().isPresent() && matcher.matches()) {
                String queryFeature = matcher.group(1);
                addQueryFeatureTypeToRankProfiles(queryFeature, tensorFieldType.type().get().toString());
            }
        }
    }

    private void addQueryFeatureTypeToRankProfiles(String queryFeature, String queryFeatureType) {
        for (RankProfile profile : rankProfileRegistry.allRankProfiles()) {
            profile.addQueryFeatureType(queryFeature, queryFeatureType);
        }
    }

}
